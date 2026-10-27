-- Any segment of the project called chore or chores (Home.Chores, Chores.Kitchen), whatever its case.
local function has_chore_segment(project)
	for segment in project:gmatch("[^.]+") do
		local s = segment:lower()
		if s == "chore" or s == "chores" then
			return true
		end
	end
	return false
end

-- The project's first segment: FUL, FUL.Billing...
local function first_segment(project)
	return project:match("^[^.]+")
end

function on_add(task)
	local project = task.project

	if project ~= nil and has_chore_segment(project) then
		task.tags:add("chore")
	end

	local ful = project ~= nil and first_segment(project) == "FUL"
	local jira_tag = task.tags:has("jira")
	local jira_uda = task.jira ~= nil and task.jira ~= ""

	if ful or jira_tag or jira_uda then
		task.tags:add("work")
	end
end
