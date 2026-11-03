--[[
    The panel on screen, for a device no MCP reaches: a button for each job
    name it is given, a caption for what is playing or a click's figures,
    and the last job's report in a scrolling text
--]]

--!strict
local Players = game:GetService("Players")

local CAPTION_HEIGHT: number = 0.1 -- The caption's share of the frame's height
local RESULT_HEIGHT: number = 0.45 -- The result scroll's share, the buttons sharing what the two leave

local Panel = {
	_caption = nil :: TextLabel?,
	_result = nil :: TextLabel?,
}

--[[
    Builds the panel in the player's PlayerGui for the session, one button
    for each name in order, each pressing the name
--]]

function Panel.build(self: Self, names: { string }, press: (name: string) -> ())
	-- Boot-time wait: the client may not have its PlayerGui yet
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

	local gui: ScreenGui = Instance.new("ScreenGui")
	gui.Name = "EchoDev"
	gui.ResetOnSpawn = false

	local frame: Frame = Instance.new("Frame")
	frame.Position = UDim2.fromScale(0.01, 0.2)
	frame.Size = UDim2.fromScale(0.3, 0.7)
	frame.BackgroundTransparency = 0.3
	frame.Parent = gui

	local layout: UIListLayout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local caption: TextLabel = Instance.new("TextLabel")
	caption.LayoutOrder = 0
	caption.Size = UDim2.fromScale(1, CAPTION_HEIGHT)
	caption.TextScaled = true
	caption.TextWrapped = true
	caption.Text = ""
	caption.Parent = frame

	-- The frame's whole height, 1, less the caption and the result, split evenly however many buttons there are
	local buttonHeight: number = (1 - CAPTION_HEIGHT - RESULT_HEIGHT) / #names

	for index: number, name: string in names do
		local button: TextButton = Instance.new("TextButton")
		button.Name = name
		button.LayoutOrder = index
		button.Size = UDim2.fromScale(1, buttonHeight)
		button.TextScaled = true
		button.Text = name
		button.Parent = frame

		-- Lives for the client session, like the panel
		button.Activated:Connect(function ()
			press(name)
		end)
	end

	local scroll: ScrollingFrame = Instance.new("ScrollingFrame")
	scroll.LayoutOrder = #names + 1
	scroll.Size = UDim2.fromScale(1, RESULT_HEIGHT)
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = frame

	local result: TextLabel = Instance.new("TextLabel")
	result.Size = UDim2.fromScale(1, 0)
	result.AutomaticSize = Enum.AutomaticSize.Y
	result.TextWrapped = true
	result.TextXAlignment = Enum.TextXAlignment.Left
	result.TextYAlignment = Enum.TextYAlignment.Top
	result.Text = ""
	result.Parent = scroll

	gui.Parent = playerGui
	self._caption = caption
	self._result = result
end

function Panel.caption(self: Self, text: string)
	local label: TextLabel? = self._caption
	if label then
		label.Text = text
	end
end

function Panel.show(self: Self, text: string)
	local label: TextLabel? = self._result
	if label then
		label.Text = text
	end
end

type Self = typeof(Panel)

return Panel
