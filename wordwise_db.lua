-- Word Wise data layer.
--
-- The plugin is dictionary-agnostic: it reads a single canonical SQLite schema
-- and does not care how the database was produced. Ship nothing; the user
-- supplies a database at <data>/wordwise/ (see build_wordwise_db.py, which can
-- derive one from a Kindle WordWise.kll dictionary for personal use, or any
-- other source rebuilt into the same shape).
--
-- Canonical schema:
--   entries(word TEXT PRIMARY KEY COLLATE NOCASE,
--           short_def TEXT NOT NULL,
--           difficulty INTEGER NOT NULL,   -- 1 rarest .. 5 most common
--           pos TEXT)
--
-- A word is glossed when its difficulty <= the user's hint level, so a low
-- hint level shows only rare/hard words and a high one also shows common ones.
local SQ3 = require("lua-ljsqlite3/init")
local logger = require("logger")

local LOOKUP_SQL = "SELECT short_def, difficulty FROM entries WHERE word = ?1 LIMIT 1;"

local WordWiseDB = {}
WordWiseDB.__index = WordWiseDB

-- Glosses are shown in full, untrimmed -- just tidy surrounding whitespace.
local function shorten(def)
    if not def or def == "" then return nil end
    def = def:gsub("^%s+", ""):gsub("%s+$", "")
    if def == "" then return nil end
    return def
end

-- Generate only plausible English lemma (base form), with spelling-change rules before
-- the generic suffix rules. In particular, married/studied must become marry/study,
-- never marri/studi (which may be unrelated dictionary lemma).
local function candidates(w)
    local out = { w }
    local seen = { [w] = true }
    local function add(s)
        if s and #s >= 3 and not seen[s] then
            seen[s] = true
            out[#out + 1] = s
        end
    end
    local n = #w

    if n >= 5 and w:sub(-3) == "ies" then
        add(w:sub(1, n - 3) .. "y")            -- studies -> study
    elseif n >= 5 and w:sub(-2) == "es" then
        add(w:sub(1, n - 2))                   -- boxes -> box
    elseif n >= 4 and w:sub(-1) == "s" then
        add(w:sub(1, n - 1))                   -- traditions -> tradition
    end

    if n >= 5 and w:sub(-2) == "ly" then
        add(w:sub(1, n - 2))                   -- splendidly -> splendid
    end

    if n >= 5 and w:sub(-3) == "ied" then
        add(w:sub(1, n - 3) .. "y")            -- married -> marry
    elseif n >= 4 and w:sub(-2) == "ed" then
        local stem = w:sub(1, n - 2)
        add(w:sub(1, n - 1))                   -- loved -> love
        if #stem >= 2 and stem:sub(-1) == stem:sub(-2, -2) then
            add(stem:sub(1, -2))               -- stopped -> stop
        end
        add(stem)                               -- walked -> walk
    end

    if n >= 5 and w:sub(-3) == "ing" then
        local stem = w:sub(1, n - 3)
        if w:sub(-4) == "ying" then
            add(w:sub(1, n - 4) .. "ie")       -- lying -> lie
        end
        add(stem .. "e")                       -- making -> make
        if #stem >= 2 and stem:sub(-1) == stem:sub(-2, -2) then
            add(stem:sub(1, -2))               -- running -> run
        end
        add(stem)                               -- hurrying -> hurry
    end
    return out
end

function WordWiseDB.open(path)
    local ok, conn = pcall(SQ3.open, path)
    if not ok or not conn then
        logger.warn("WordWiseDB: cannot open", path, tostring(conn))
        return nil
    end
    local self = setmetatable({ conn = conn, cache = {} }, WordWiseDB)
    local ok2, stmt = pcall(function() return conn:prepare(LOOKUP_SQL) end)
    if not ok2 or not stmt then
        logger.warn("WordWiseDB: prepare failed", tostring(stmt))
        pcall(function() conn:close() end)
        return nil
    end
    self.stmt = stmt
    return self
end

-- One raw lookup of an exact key. Returns {gloss, difficulty} or nil.
function WordWiseDB:_query(key)
    local result = nil
    local ok, err = pcall(function()
        self.stmt:reset():clearbind()
        self.stmt:bind(key)
        local row = self.stmt:step()
        if row then
            local gloss = shorten(row[1])
            local difficulty = tonumber(row[2])
            if gloss and difficulty then
                -- key is the lemma that actually matched (a de-inflected
                -- candidate), so callers can suppress every surface form of it.
                result = { gloss = gloss, difficulty = difficulty, key = key }
            end
        end
        self.stmt:clearbind():reset()
    end)
    if not ok then
        logger.warn("WordWiseDB: lookup failed for", key, tostring(err))
    end
    return result
end

function WordWiseDB:lookup(word)
    local key = word:lower()
    local cached = self.cache[key]
    if cached ~= nil then
        return cached or nil
    end
    local result = nil
    for _, cand in ipairs(candidates(key)) do
        result = self:_query(cand)
        if result then break end
    end
    self.cache[key] = result or false
    return result
end


-- Return { gloss = <string>, difficulty = <int> } or nil. Cached per surface
-- word (including negative results). Tries the word, then de-inflected forms.
function WordWiseDB:close()
    if self.stmt then pcall(function() self.stmt:close() end) end
    if self.conn then pcall(function() self.conn:close() end) end
    self.stmt, self.conn = nil, nil
end

return WordWiseDB
