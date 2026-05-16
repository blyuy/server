if SERVER then return end

surface.CreateFont("NexusLockpickTitle", {
    font = "Roboto",
    size = 42,
    weight = 700,
    antialias = true
})

surface.CreateFont("NexusLockpickHeader", {
    font = "Roboto",
    size = 40,
    weight = 500,
    antialias = true
})

surface.CreateFont("NexusLockpickText", {
    font = "Roboto",
    size = 18,
    weight = 500,
    antialias = true
})

local PANEL = {}

function PANEL:Init()
    self:SetSize(440, 220)
    self:Center()
    self:SetTitle("")
    self:SetDraggable(false)
    self:ShowCloseButton(false)
    self:SetDeleteOnClose(true)

    self.required = 6
    self.hits = 0
    self.endsAt = CurTime() + 42
    self.goalStart = 0.35
    self.goalSize = 0.20
    self.marker = 0
    self.direction = 1
    self.statusText = "Попадите в зеленую зону несколько раз"
    self.lastInput = 0

    self.actionButton = vgui.Create("DButton", self)
    self.actionButton:SetText("")
    self.actionButton.DoClick = function()
        self:TryHit()
    end
end

function PANEL:Setup(required, seconds)
    self.required = required or 6
    self.hits = 0
    self.endsAt = CurTime() + (seconds or 42)
end

function PANEL:Think()
    local dt = FrameTime() * 0.75
    self.marker = self.marker + (dt * self.direction)

    if self.marker >= 1 then
        self.marker = 1
        self.direction = -1
    elseif self.marker <= 0 then
        self.marker = 0
        self.direction = 1
    end

    if self.endsAt <= CurTime() then
        net.Start("nexus_lockpick_input")
        net.WriteBool(false)
        net.SendToServer()
        self:Close()
        return
    end

    self.actionButton:SetPos(110, 156)
    self.actionButton:SetSize(self:GetWide() - 220, 38)
end

function PANEL:Paint(w, h)
    draw.RoundedBox(10, 0, 0, w, h, Color(33, 15, 19, 236))
    draw.SimpleText("NEXUS", "NexusLockpickTitle", w * 0.5, 14, Color(255, 255, 255, 230), TEXT_ALIGN_CENTER)
    draw.SimpleText("Взлом замка", "NexusLockpickHeader", w * 0.5, 52, color_white, TEXT_ALIGN_CENTER)
    draw.SimpleText(self.statusText, "NexusLockpickText", w * 0.5, 98, Color(210, 210, 220), TEXT_ALIGN_CENTER)

    local smallX, smallY, smallW, smallH = 40, 118, w - 80, 14
    draw.RoundedBox(6, smallX, smallY, smallW, smallH, Color(43, 48, 66, 245))
    draw.SimpleText(self.hits .. " / " .. self.required, "NexusLockpickText", w * 0.5, smallY + (smallH * 0.5), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local barX, barY, barW, barH = 40, 140, w - 80, 28
    draw.RoundedBox(8, barX, barY, barW, barH, Color(43, 48, 66, 245))
    draw.RoundedBox(8, barX + (barW * self.goalStart), barY, barW * self.goalSize, barH, Color(58, 182, 88, 255))
    draw.RoundedBox(0, barX + (barW * self.marker) - 2, barY - 2, 4, barH + 4, color_white)

    draw.RoundedBox(8, 110, 156, w - 220, 38, Color(61, 103, 177, 255))
    draw.SimpleText("Взломать", "NexusLockpickText", w * 0.5, 174, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local left = math.max(0, math.ceil(self.endsAt - CurTime()))
    draw.SimpleText("Время раунда: 0:" .. string.format("%02d", left), "NexusLockpickText", w * 0.5, 204, Color(210, 210, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:TryHit()
    if self.lastInput > CurTime() then return end
    self.lastInput = CurTime() + 0.2

    local success = self.marker >= self.goalStart and self.marker <= (self.goalStart + self.goalSize)

    net.Start("nexus_lockpick_input")
    net.WriteBool(success)
    net.SendToServer()

    if success then
        self.statusText = "Точное попадание"
        self.goalStart = math.Rand(0.08, 0.72)
    else
        self.statusText = "Промах"
    end
end

vgui.Register("NexusLockpickFrame", PANEL, "DFrame")

local lockpickFrame

net.Receive("nexus_lockpick_open", function()
    local required = net.ReadUInt(8)
    local seconds = net.ReadUInt(8)

    if IsValid(lockpickFrame) then
        lockpickFrame:Remove()
    end

    lockpickFrame = vgui.Create("NexusLockpickFrame")
    lockpickFrame:Setup(required, seconds)
    lockpickFrame:MakePopup()
end)

net.Receive("nexus_lockpick_update", function()
    local hits = net.ReadUInt(8)
    local required = net.ReadUInt(8)

    if not IsValid(lockpickFrame) then return end

    lockpickFrame.hits = hits
    lockpickFrame.required = required
end)

net.Receive("nexus_lockpick_close", function()
    local success = net.ReadBool()
    local message = net.ReadString()

    if IsValid(lockpickFrame) then
        lockpickFrame:Remove()
    end

    chat.AddText(success and Color(90, 220, 120) or Color(220, 80, 80), "[NEXUS] ", color_white, message)
end)

concommand.Add("nexus_lockpick", function()
    net.Start("nexus_lockpick_request")
    net.SendToServer()
end)