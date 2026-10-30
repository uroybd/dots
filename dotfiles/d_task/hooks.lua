-- True if any period-separated segment of project matches any of segments (a string or a list of strings)
-- literally. With partial, a candidate may match anywhere inside a project segment (chore matches chorexxx, never
-- chor); otherwise it must equal the whole project segment. A nil project (a task with no project) never matches.
local function segment_matches(project, segments, case_insensitive, partial)
	if project == nil then
		return false
	end
	if type(segments) == "string" then
		segments = { segments }
	end
	if case_insensitive then
		project = project:lower()
	end
	for part in project:gmatch("[^.]+") do
		for _, segment in ipairs(segments) do
			if case_insensitive then
				segment = segment:lower()
			end
			if partial then
				if part:find(segment, 1, true) then
					return true
				end
			elseif part == segment then
				return true
			end
		end
	end
	return false
end

-- The project's nth segment (1-based), or nil if there are fewer or no project: nth_segment("FUL.Billing", 2) is
-- "Billing".
local function nth_segment(project, n)
	if project == nil then
		return nil
	end
	local i = 0
	for segment in project:gmatch("[^.]+") do
		i = i + 1
		if i == n then
			return segment
		end
	end
end

-- Rules run by on_add, in order. Each entry has a match function (takes the task, returns true if the rule applies) and
-- a metadata table to apply to the task when it does (the keys are listed at apply_metadata).
local on_add_autometa = {
	{
		match = function(task)
			return segment_matches(task.project, { "chore", "chores" }, true, false)
		end,
		metadata = {
			tags = { "chore" },
		},
	},
	{
		match = function(task)
			return nth_segment(task.project, 1) == "FUL"
				or task.tags:has("jira")
				or (task.jira ~= nil and task.jira ~= "")
		end,
		metadata = {
			tags = { "work" },
		},
	},
}

local function as_list(value)
	return type(value) == "string" and { value } or value
end

local function is_unset(value)
	return value == nil or value == ""
end

-- Applies one metadata table to a task. A value may be a function of the task, for something computed. Keys:
--   tags, depends   add to the set (a list, or one string)
--   remove_tags     take out of tags
--   anything else   a field (project, priority, due, wait, scheduled, until, a UDA...) set only if the task has no value
--                   for it yet, so what was typed on the command line wins. Dates take "tomorrow", "now+3d", a date().
local function apply_metadata(task, metadata)
	for key, value in pairs(metadata) do
		if type(value) == "function" then
			value = value(task)
		end
		if key == "tags" or key == "depends" then
			for _, item in ipairs(as_list(value)) do
				task[key]:add(item)
			end
		elseif key == "remove_tags" then
			for _, tag in ipairs(as_list(value)) do
				task.tags:remove(tag)
			end
		elseif value ~= nil and is_unset(task[key]) then
			task[key] = value
		end
	end
end

function on_add(task)
	for _, entry in ipairs(on_add_autometa) do
		if entry.match(task) then
			apply_metadata(task, entry.metadata)
		end
	end
end

-- A task that is done without an outcome (task 1 done) succeeded; one finished with outcome:failed stays failed.
function on_modify(old, new)
	if old.status ~= "completed" and new.status == "completed" and is_unset(new.outcome) then
		new.outcome = "success"
	end
end
