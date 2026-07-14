local EZOCore = EZOCore

-- Central settings service for the EZO family.
-- It owns a native Settings > EZO entry and renders registered LibAddonMenu
-- controls inside a shared EZO settings window.

local SETTINGS = {}
EZOCore.Settings = SETTINGS

local PANEL_NAME = "EZO"
local PANEL_DISPLAY_NAME = "E|cB040FFZ|rO"
local FEEDBACK_URL = "https://discord.gg/ekw8zUAcRm"
local SERVICE_NAME = "family.settings"
local SERVICE_API_VERSION = 1
local CORE_ADDON_NAME = "EZOCore"
local MANAGER_PANEL_ID = "__ezo_installed_addons"
local HUB_PANEL_ID = "EZOCore_EZO_Panel"
local WINDOW_NAME = "EZOCoreSettingsWindow"

local panelsById = {}
local panelOrder = {}
local hubOptions = {}
local ui
local panelId
local selectedPanelId
local createdSettingsPanel = false
local createdLamHubPanel = false
local controlCounter = 0

SETTINGS.reloadRequired = false

local STRINGS = {
    en = {
        installedAddons = "Installed EZO addons",
        installedAddonsTooltip = "Enable or disable installed EZO family addons. Changes require reload.",
        noOptions = "This addon has not registered settings yet.",
        noLam = "LibAddonMenu-2.0 is not available. Option controls cannot be rendered.",
        unsupportedControl = "Unsupported setting control: %s",
        addOnManagerUnavailable = "The ESO addon manager API is not available in this context.",
        reloadUi = "Reload UI",
        reloadUiTooltip = "Apply addon enable/disable changes.",
        reloadRequired = "Reload required to apply addon load changes.",
        coreProtected = "EZOCore cannot be disabled from this panel.",
        enabled = "Enabled",
        disabled = "Disabled",
        folder = "Folder: %s",
        state = "State: %s",
        hubDescription = "Central access point for EZO family addon settings.",
        addonSettings = "Addon settings",
    },
    es = {
        installedAddons = "Addons EZO instalados",
        installedAddonsTooltip = "Activa o desactiva addons instalados de la familia EZO. "
            .. "Los cambios requieren recarga.",
        noOptions = "Este addon todavia no ha registrado opciones.",
        noLam = "LibAddonMenu-2.0 no esta disponible. No se pueden dibujar controles de opciones.",
        unsupportedControl = "Control de ajuste no soportado: %s",
        addOnManagerUnavailable = "La API del gestor de addons de ESO no esta disponible en este contexto.",
        reloadUi = "Recargar UI",
        reloadUiTooltip = "Aplica cambios de carga/descarga de addons.",
        reloadRequired = "Hace falta recargar para aplicar cambios de carga de addons.",
        coreProtected = "EZOCore no se puede desactivar desde este panel.",
        enabled = "Activado",
        disabled = "Desactivado",
        folder = "Carpeta: %s",
        state = "Estado: %s",
        hubDescription = "Acceso central a la configuracion de los addons de la familia EZO.",
        addonSettings = "Configuracion de addons",
    },
}

local function GetLanguage()
    if type(GetCVar) == "function" then
        local value = GetCVar("Language.2")
        if type(value) == "string" and string.lower(value) == "es" then
            return "es"
        end
    end
    return "en"
end

local function T(key, ...)
    local lang = GetLanguage()
    local text = (STRINGS[lang] and STRINGS[lang][key]) or STRINGS.en[key] or key
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then
            return formatted
        end
    end
    return text
end

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function NormalizeId(value)
    if not IsNonEmptyString(value) then
        return nil
    end

    local id = string.lower(value)
    if not string.match(id, "^[%w%.%-_]+$") then
        return nil
    end
    return id
end

local function StripMarkup(value)
    local text = tostring(value or "")
    text = string.gsub(text, "|[Cc]%x%x%x%x%x%x", "")
    text = string.gsub(text, "|[Rr]", "")
    return text
end

local function SortPanels()
    table.sort(panelOrder, function(leftId, rightId)
        local left = panelsById[leftId]
        local right = panelsById[rightId]
        local leftName = left and left.sortName or leftId
        local rightName = right and right.sortName or rightId
        return leftName < rightName
    end)
end

local function GetLam()
    if type(LibAddonMenu2) == "table" then
        return LibAddonMenu2
    end
    return nil
end

local function GetAddOnManager()
    if type(AddOnManager) == "table" then
        return AddOnManager
    end
    if type(ADD_ON_MANAGER) == "table" then
        return ADD_ON_MANAGER
    end
    return nil
end

local function GetAddOnCount(manager)
    if not manager or type(manager.GetNumAddOns) ~= "function" then
        return nil
    end

    local ok, count = pcall(function()
        return manager:GetNumAddOns()
    end)
    if ok and type(count) == "number" then
        return count
    end
    return nil
end

local function GetAddOnInfo(manager, index)
    if not manager or type(manager.GetAddOnInfo) ~= "function" then
        return nil
    end

    local ok, name, title, author, description, enabled, state, isOutOfDate, isLibrary = pcall(function()
        return manager:GetAddOnInfo(index)
    end)
    if not ok then
        return nil
    end

    return {
        index = index,
        name = tostring(name or ""),
        title = tostring(title or name or ""),
        author = author,
        description = description,
        enabled = enabled == true,
        state = state,
        isOutOfDate = isOutOfDate == true,
        isLibrary = isLibrary == true,
    }
end

local function IsEZOAddon(record)
    if not record or record.isLibrary then
        return false
    end

    local folder = StripMarkup(record.name)
    local title = StripMarkup(record.title)
    if folder == CORE_ADDON_NAME then
        return false
    end

    return string.match(folder, "^EZO") ~= nil
        or string.match(title, "^EZO") ~= nil
        or string.find(string.lower(title), "ezo", 1, true) ~= nil
end

local function GetInstalledEZOAddons()
    local manager = GetAddOnManager()
    local count = GetAddOnCount(manager)
    local addons = {}

    if not count then
        return addons
    end

    for index = 1, count do
        local record = GetAddOnInfo(manager, index)
        if IsEZOAddon(record) then
            addons[#addons + 1] = record
        end
    end

    table.sort(addons, function(left, right)
        return string.lower(StripMarkup(left.title)) < string.lower(StripMarkup(right.title))
    end)

    return addons
end

local function CanSetAddOnEnabled()
    local manager = GetAddOnManager()
    return manager and type(manager.SetAddOnEnabled) == "function"
end

local function SetAddOnEnabled(record, enabled)
    local manager = GetAddOnManager()
    if not record or not manager or type(manager.SetAddOnEnabled) ~= "function" then
        return false
    end

    local ok = pcall(function()
        manager:SetAddOnEnabled(record.index, enabled == true)
    end)
    if ok then
        record.enabled = enabled == true
        SETTINGS.reloadRequired = true
        SETTINGS:RefreshCurrentPanel()
        return true
    end
    return false
end

local function CreateLabel(parent, name, text, font)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font or "ZoFontGame")
    label:SetText(text)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return label
end

local function ClearControls(controls)
    if type(controls) ~= "table" then
        return
    end

    for _, control in ipairs(controls) do
        if control and type(control.SetHidden) == "function" then
            control:SetHidden(true)
        end
    end
    for key in pairs(controls) do
        controls[key] = nil
    end
end

local function FireLamCallback(callbackName, panel)
    if CALLBACK_MANAGER and type(CALLBACK_MANAGER.FireCallbacks) == "function" then
        pcall(function()
            CALLBACK_MANAGER:FireCallbacks(callbackName, panel)
        end)
    end
end

local function UnsupportedControl(parent, widgetData)
    controlCounter = controlCounter + 1
    local label = CreateLabel(parent, WINDOW_NAME .. "Unsupported" .. controlCounter,
        T("unsupportedControl", tostring(widgetData and widgetData.type or "nil")))
    label:SetColor(0.95, 0.55, 0.35, 1)
    return label
end

local function PairHalfWidthControls(parent, leftWidget, rightWidget)
    local containerParent = parent.scroll or parent
    local panel = parent.panel or containerParent

    controlCounter = controlCounter + 1
    local container = WINDOW_MANAGER:CreateControl(
        WINDOW_NAME .. "TwinContainer" .. controlCounter,
        containerParent,
        CT_CONTROL)
    container:SetResizeToFitDescendents(true)
    container:SetAnchor(select(2, leftWidget:GetAnchor(0)))

    leftWidget:ClearAnchors()
    leftWidget:SetAnchor(TOPLEFT, container, TOPLEFT)
    rightWidget:SetAnchor(TOPLEFT, leftWidget, TOPRIGHT, 5, 0)
    leftWidget:SetWidth(leftWidget:GetWidth() - 2.5)
    rightWidget:SetWidth(rightWidget:GetWidth() - 2.5)
    leftWidget:SetParent(container)
    rightWidget:SetParent(container)

    container.data = { type = "container" }
    container.panel = panel
    return container
end

local function CreateOptionControls(parent, options)
    if not parent or type(options) ~= "table" then
        return
    end

    parent._ezoCreatedControls = parent._ezoCreatedControls or {}

    local lastControl
    local previousWasHalf = false
    for index = 1, #options do
        local widgetData = options[index]
        if type(widgetData) == "table" then
            local creator = LAMCreateControl and LAMCreateControl[widgetData.type]
            local widget

            if type(creator) == "function" then
                local ok, result = pcall(function()
                    controlCounter = controlCounter + 1
                    return creator(parent, widgetData, WINDOW_NAME .. "Control" .. controlCounter)
                end)
                if ok then
                    widget = result
                else
                    EZOCore:Warn("Settings control failed (%s): %s", tostring(widgetData.type), tostring(result))
                    widget = UnsupportedControl(parent, widgetData)
                end
            else
                widget = UnsupportedControl(parent, widgetData)
            end

            if widget then
                parent._ezoCreatedControls[#parent._ezoCreatedControls + 1] = widget
                local isHalf = widgetData.width == "half"
                if not lastControl then
                    widget:SetAnchor(TOPLEFT)
                    lastControl = widget
                    previousWasHalf = isHalf
                elseif previousWasHalf and isHalf then
                    lastControl = PairHalfWidthControls(parent, lastControl, widget)
                    parent._ezoCreatedControls[#parent._ezoCreatedControls + 1] = lastControl
                    previousWasHalf = false
                else
                    widget:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 15)
                    lastControl = widget
                    previousWasHalf = isHalf
                end

                if widgetData.type == "submenu" and type(widgetData.controls) == "table" then
                    widget._ezoCreatedControls = {}
                    CreateOptionControls(widget, widgetData.controls)
                end
            end
        end
    end
end

local function ResolveOptions(entry)
    if not entry then
        return nil
    end

    if type(entry.options) == "function" then
        local ok, result = pcall(entry.options)
        if ok and type(result) == "table" then
            return result
        end
        EZOCore:Warn("Settings panel '%s' failed to build options", entry.addonId)
        return nil
    end

    if type(entry.options) == "table" then
        return entry.options
    end

    return nil
end

local function BuildInstalledAddonsOptions()
    local manager = GetAddOnManager()
    local count = GetAddOnCount(manager)
    local canSet = CanSetAddOnEnabled()
    local options = {
        {
            type = "description",
            text = T("installedAddonsTooltip"),
        },
    }

    if not count then
        options[#options + 1] = {
            type = "description",
            text = T("addOnManagerUnavailable"),
        }
        return options
    end

    local addons = GetInstalledEZOAddons()
    for _, record in ipairs(addons) do
        local title = StripMarkup(record.title)
        local folder = StripMarkup(record.name)
        local state = tostring(record.state or "")
        local detail = T("folder", folder)
        if state ~= "" then
            detail = detail .. "\n" .. T("state", state)
        end

        options[#options + 1] = {
            type = "checkbox",
            name = title,
            tooltip = detail,
            getFunc = function()
                return record.enabled == true
            end,
            setFunc = function(value)
                SetAddOnEnabled(record, value == true)
            end,
            disabled = function()
                return not canSet
            end,
            width = "full",
        }
    end

    if SETTINGS.reloadRequired then
        options[#options + 1] = {
            type = "description",
            text = T("reloadRequired"),
        }
    end

    options[#options + 1] = {
        type = "button",
        name = T("reloadUi"),
        tooltip = T("reloadUiTooltip"),
        func = function()
            if type(ReloadUI) == "function" then
                ReloadUI()
            end
        end,
        disabled = function()
            return not SETTINGS.reloadRequired or type(ReloadUI) ~= "function"
        end,
        width = "half",
    }

    return options
end

local function BuildManagerEntry()
    return {
        addonId = MANAGER_PANEL_ID,
        panelId = MANAGER_PANEL_ID,
        panelData = {
            type = "panel",
            name = PANEL_NAME,
            displayName = PANEL_DISPLAY_NAME,
            author = "@Zuriplayer",
            version = EZOCore.version,
            feedback = FEEDBACK_URL,
            registerForRefresh = true,
        },
        options = BuildInstalledAddonsOptions,
        sortName = "000 " .. T("installedAddons"),
    }
end

local function RebuildHubOptions()
    for key in pairs(hubOptions) do
        hubOptions[key] = nil
    end

    hubOptions[#hubOptions + 1] = {
        type = "description",
        text = T("hubDescription"),
    }

    local addonControls = {}
    SortPanels()
    for _, addonId in ipairs(panelOrder) do
        local entry = panelsById[addonId]
        if entry then
            local panelData = entry.panelData or {}
            local displayName = StripMarkup(panelData.displayName or panelData.name or entry.addonId)
            local controls = ResolveOptions(entry)
            if type(controls) ~= "table" or #controls == 0 then
                controls = {
                    {
                        type = "description",
                        text = T("noOptions"),
                    },
                }
            end
            addonControls[#addonControls + 1] = {
                type = "submenu",
                name = displayName,
                tooltip = StripMarkup(panelData.description or ""),
                controls = controls,
            }
        end
    end

    if #addonControls == 0 then
        addonControls[#addonControls + 1] = {
            type = "description",
            text = T("noOptions"),
        }
    end

    hubOptions[#hubOptions + 1] = {
        type = "submenu",
        name = T("addonSettings"),
        controls = addonControls,
    }

    hubOptions[#hubOptions + 1] = {
        type = "submenu",
        name = T("installedAddons"),
        tooltip = T("installedAddonsTooltip"),
        controls = BuildInstalledAddonsOptions(),
    }
end

local function RegisterLamHubPanel()
    if createdLamHubPanel then
        return true
    end

    local LAM = GetLam()
    if not LAM
        or type(LAM.RegisterAddonPanel) ~= "function"
        or type(LAM.RegisterOptionControls) ~= "function" then
        return false
    end

    RebuildHubOptions()
    SETTINGS.lamPanel = LAM:RegisterAddonPanel(HUB_PANEL_ID, {
        type = "panel",
        name = PANEL_NAME,
        displayName = PANEL_DISPLAY_NAME,
        author = "@Zuriplayer",
        version = EZOCore.version,
        feedback = FEEDBACK_URL,
        registerForRefresh = true,
    })
    LAM:RegisterOptionControls(HUB_PANEL_ID, hubOptions)
    createdLamHubPanel = SETTINGS.lamPanel ~= nil
    return createdLamHubPanel
end

local function GetEntry(addonId)
    if addonId == MANAGER_PANEL_ID then
        return BuildManagerEntry()
    end
    return panelsById[addonId]
end

local function SelectFirstPanel()
    if selectedPanelId then
        return
    end
    selectedPanelId = MANAGER_PANEL_ID
end

local function RebuildMenuList()
    if not ui then
        return
    end

    ClearControls(ui.menuRows)

    local rows = {
        BuildManagerEntry(),
    }
    SortPanels()
    for _, addonId in ipairs(panelOrder) do
        rows[#rows + 1] = panelsById[addonId]
    end

    local previous
    for _, entry in ipairs(rows) do
        controlCounter = controlCounter + 1
        local row = CreateLabel(ui.menuChild, WINDOW_NAME .. "MenuRow" .. controlCounter,
            StripMarkup(entry.panelData.displayName or entry.panelData.name or entry.addonId),
            "ZoFontGame")
        row:SetDimensions(260, 28)
        row:SetMouseEnabled(true)
        row:SetHandler("OnMouseUp", function()
            SETTINGS:OpenSettingsPanel(entry.addonId)
        end)
        row:SetHandler("OnMouseEnter", function(control)
            control:SetColor(1, 0.84, 0.45, 1)
        end)
        row:SetHandler("OnMouseExit", function(control)
            if selectedPanelId == entry.addonId then
                control:SetColor(1, 1, 1, 1)
            else
                control:SetColor(0.78, 0.78, 0.72, 1)
            end
        end)
        if selectedPanelId == entry.addonId then
            row:SetColor(1, 1, 1, 1)
        else
            row:SetColor(0.78, 0.78, 0.72, 1)
        end

        if previous then
            row:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 6)
        else
            row:SetAnchor(TOPLEFT, ui.menuChild, TOPLEFT, 0, 0)
        end
        previous = row
        ui.menuRows[#ui.menuRows + 1] = row
    end
end

local function RenderSelectedPanel()
    if not ui then
        return
    end

    local previousPanelId = ui.currentPanelId
    if ui.currentPanelHost and previousPanelId ~= selectedPanelId then
        FireLamCallback("LAM-PanelClosed", ui.currentPanelHost)
        ui.currentPanelHost:SetHidden(true)
        ui.currentPanelHost = nil
    end

    local entry = GetEntry(selectedPanelId)
    if not entry then
        SelectFirstPanel()
        entry = GetEntry(selectedPanelId)
    end
    if not entry then
        return
    end

    local existingHost = ui.panelHosts[selectedPanelId]
    if existingHost then
        existingHost:SetHidden(false)
        ui.currentPanelHost = existingHost
        ui.currentPanelId = selectedPanelId
        FireLamCallback("LAM-RefreshPanel", existingHost)
        if previousPanelId ~= selectedPanelId then
            FireLamCallback("LAM-PanelOpened", existingHost)
        end
        RebuildMenuList()
        return
    end

    local panelData = entry.panelData or {}
    local options = ResolveOptions(entry)
    if GetLam()
        and type(LAMCreateControl) == "table"
        and type(LAMCreateControl.panel) == "function"
        and type(options) == "table"
        and #options > 0 then
        controlCounter = controlCounter + 1
        local panelHost = LAMCreateControl.panel(
            ui.optionChild,
            panelData,
            WINDOW_NAME .. "LAMPanel" .. controlCounter)
        panelHost:SetDimensions(645, 675)
        panelHost:SetAnchor(TOPLEFT, ui.optionChild, TOPLEFT, 0, 0)
        panelHost:SetHidden(false)
        panelHost._ezoCreatedControls = {}
        ui.panelHosts[selectedPanelId] = panelHost
        ui.currentPanelHost = panelHost
        ui.currentPanelId = selectedPanelId

        CreateOptionControls(panelHost, options)
        FireLamCallback("LAM-PanelControlsCreated", panelHost)
        FireLamCallback("LAM-RefreshPanel", panelHost)
        FireLamCallback("LAM-PanelOpened", panelHost)
    else
        controlCounter = controlCounter + 1
        local panelHost = WINDOW_MANAGER:CreateControl(
            WINDOW_NAME .. "FallbackPanel" .. controlCounter,
            ui.optionChild,
            CT_CONTROL)
        panelHost:SetDimensions(645, 675)
        panelHost:SetAnchor(TOPLEFT, ui.optionChild, TOPLEFT, 0, 0)

        controlCounter = controlCounter + 1
        local info = CreateLabel(panelHost, WINDOW_NAME .. "PanelInfo" .. controlCounter, "", "ZoFontGameSmall")
        info:SetDimensions(645, 40)
        info:SetColor(0.72, 0.72, 0.68, 1)
        info:SetAnchor(TOPLEFT, panelHost, TOPLEFT, 0, 0)

        local infoParts = {}
        if IsNonEmptyString(panelData.author) then
            infoParts[#infoParts + 1] = tostring(panelData.author)
        end
        if IsNonEmptyString(panelData.version) then
            infoParts[#infoParts + 1] = "v" .. tostring(panelData.version)
        end
        info:SetText(table.concat(infoParts, "  "))

        local message = T("noOptions")
        if not GetLam() then
            message = T("noLam")
        end

        controlCounter = controlCounter + 1
        local label = CreateLabel(panelHost, WINDOW_NAME .. "Empty" .. controlCounter, message)
        label:SetDimensions(645, 80)
        label:SetColor(0.9, 0.82, 0.62, 1)
        label:SetAnchor(TOPLEFT, info, BOTTOMLEFT, 0, 15)

        ui.panelHosts[selectedPanelId] = panelHost
        ui.currentPanelHost = panelHost
        ui.currentPanelId = selectedPanelId
    end

    RebuildMenuList()
end

local function CreateSettingsWindow()
    if ui or not WINDOW_MANAGER or not GuiRoot then
        return ui ~= nil
    end

    local root = WINDOW_MANAGER:CreateTopLevelWindow(WINDOW_NAME)
    root:SetDimensions(1010, 914)
    root:SetAnchor(LEFT, GuiRoot, LEFT, 245, 0)
    root:SetHidden(true)

    local bgLeft = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "BackgroundLeft", root, CT_TEXTURE)
    bgLeft:SetDimensions(1024, 1024)
    bgLeft:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
    bgLeft:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_left.dds")
    bgLeft:SetDrawLayer(DL_BACKGROUND)

    local bgRight = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "BackgroundRight", root, CT_TEXTURE)
    bgRight:SetDimensions(64, 1024)
    bgRight:SetAnchor(TOPLEFT, bgLeft, TOPRIGHT, 0, 0)
    bgRight:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_right.dds")
    bgRight:SetDrawLayer(DL_BACKGROUND)

    local underlayLeft = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "UnderlayLeft", root, CT_TEXTURE)
    underlayLeft:SetDimensions(256, 1024)
    underlayLeft:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
    underlayLeft:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_indexArea_left.dds")
    underlayLeft:SetDrawLayer(DL_BACKGROUND)

    local underlayRight = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "UnderlayRight", root, CT_TEXTURE)
    underlayRight:SetDimensions(128, 1024)
    underlayRight:SetAnchor(TOPLEFT, underlayLeft, TOPRIGHT, 0, 0)
    underlayRight:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_indexArea_right.dds")
    underlayRight:SetDrawLayer(DL_BACKGROUND)

    local title = CreateLabel(root, WINDOW_NAME .. "Title", PANEL_DISPLAY_NAME, "ZoFontWinH1")
    title:SetDimensions(900, 30)
    title:SetAnchor(TOPLEFT, root, TOPLEFT, 65, 70)

    local divider = WINDOW_MANAGER:CreateControlFromVirtual(
        WINDOW_NAME .. "Divider",
        root,
        "ZO_Options_Divider")
    divider:SetAnchor(TOPLEFT, root, TOPLEFT, 65, 108)

    local menuContainer = WINDOW_MANAGER:CreateControlFromVirtual(
        WINDOW_NAME .. "MenuScroll",
        root,
        "ZO_ScrollContainer")
    menuContainer:SetDimensions(285, 665)
    menuContainer:SetAnchor(TOPLEFT, root, TOPLEFT, 65, 160)
    local menuChild = GetControl(menuContainer, "ScrollChild")
    menuChild:SetResizeToFitPadding(0, 20)

    local optionContainer = WINDOW_MANAGER:CreateControl(
        WINDOW_NAME .. "OptionsHost",
        root,
        CT_CONTROL)
    optionContainer:SetDimensions(645, 675)
    optionContainer:SetAnchor(TOPLEFT, root, TOPLEFT, 365, 120)
    local optionChild = optionContainer

    ui = {
        root = root,
        title = title,
        menuContainer = menuContainer,
        menuChild = menuChild,
        optionContainer = optionContainer,
        optionChild = optionChild,
        menuRows = {},
        panelHosts = {},
        background = { bgLeft, bgRight, underlayLeft, underlayRight, divider },
    }

    if type(ZO_FadeSceneFragment) == "table" and type(ZO_FadeSceneFragment.New) == "function" then
        ui.fragment = ZO_FadeSceneFragment:New(root, true, 100)
    elseif type(ZO_SimpleSceneFragment) == "table" and type(ZO_SimpleSceneFragment.New) == "function" then
        ui.fragment = ZO_SimpleSceneFragment:New(root)
    end

    if ui.fragment and type(ui.fragment.RegisterCallback) == "function" then
        ui.fragment:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_FRAGMENT_SHOWN and type(PushActionLayerByName) == "function" then
                PushActionLayerByName("OptionsWindow")
            elseif newState == SCENE_FRAGMENT_HIDDEN and type(RemoveActionLayerByName) == "function" then
                RemoveActionLayerByName("OptionsWindow")
            end
        end)
    end

    SelectFirstPanel()
    RebuildMenuList()

    return true
end

local function SelectSettingsNode()
    if not panelId or not ZO_GameMenu_InGame or not ZO_GameMenu_InGame.gameMenu then
        return
    end

    local settingsLabel = GetString(SI_GAME_MENU_SETTINGS)
    local settingsMenu = ZO_GameMenu_InGame.gameMenu.headerControls[settingsLabel]
    if not settingsMenu then
        return
    end

    local children = { settingsMenu:GetChildren() }
    for index = 1, (children and #children or 0) do
        local child = children[index]
        local data = child:GetData()
        if data and data.id == panelId then
            child:GetTree():SelectNode(child)
            return
        end
    end
end

local function RegisterNativeSettingsPanel()
    if createdSettingsPanel then
        return true
    end
    if not KEYBOARD_OPTIONS or type(ZO_GameMenu_AddSettingPanel) ~= "function" then
        return false
    end
    if not CreateSettingsWindow() then
        return false
    end

    panelId = KEYBOARD_OPTIONS.currentPanelId
    local nativePanelData = {
        id = panelId,
        name = PANEL_NAME,
        callback = function()
            if ui and ui.fragment and SCENE_MANAGER then
                SCENE_MANAGER:AddFragment(ui.fragment)
            end
            if ui and ui.root then
                ui.root:SetHidden(false)
            end
            RenderSelectedPanel()
        end,
        unselectedCallback = function()
            if ui and ui.fragment and SCENE_MANAGER then
                SCENE_MANAGER:RemoveFragment(ui.fragment)
            end
            if ui and ui.root then
                ui.root:SetHidden(true)
            end
        end,
    }

    KEYBOARD_OPTIONS.currentPanelId = panelId + 1
    KEYBOARD_OPTIONS.panelNames[panelId] = nativePanelData.name
    ZO_GameMenu_AddSettingPanel(nativePanelData)

    createdSettingsPanel = true
    return true
end

function SETTINGS.RegisterSettingsPanel(_, addonId, addonPanelId, panelData, options, lamPanel)
    local normalizedId = NormalizeId(addonId)
    if not normalizedId then
        EZOCore:Warn("RegisterSettingsPanel: addonId must be a stable non-empty id")
        return false
    end
    if normalizedId == NormalizeId(CORE_ADDON_NAME) then
        EZOCore:Warn("RegisterSettingsPanel: EZOCore core panel is reserved")
        return false
    end
    if not IsNonEmptyString(addonPanelId) then
        EZOCore:Warn("RegisterSettingsPanel: panelId must be a non-empty string (addon '%s')", normalizedId)
        return false
    end
    if type(panelData) ~= "table" then
        EZOCore:Warn("RegisterSettingsPanel: panelData must be a table (addon '%s')", normalizedId)
        return false
    end
    if type(options) ~= "table" and type(options) ~= "function" then
        EZOCore:Warn("RegisterSettingsPanel: options must be a table or function (addon '%s')", normalizedId)
        return false
    end

    if not panelsById[normalizedId] then
        panelOrder[#panelOrder + 1] = normalizedId
    end

    panelsById[normalizedId] = {
        addonId = normalizedId,
        panelId = addonPanelId,
        panelData = panelData,
        options = options,
        lamPanel = lamPanel,
        sortName = string.lower(StripMarkup(panelData.displayName or panelData.name or normalizedId)),
    }

    SortPanels()
    RebuildHubOptions()
    if ui then
        RebuildMenuList()
    end

    EZOCore:Info("Settings panel registered: %s", normalizedId)
    EZOCore:FireCallback("EZOCore:SettingsPanelRegistered", normalizedId, addonPanelId)
    return true
end

function SETTINGS.GetSettingsPanels()
    local list = {}
    for _, addonId in ipairs(panelOrder) do
        local entry = panelsById[addonId]
        list[#list + 1] = {
            addonId = entry.addonId,
            panelId = entry.panelId,
            panelData = entry.panelData,
        }
    end
    return list
end

function SETTINGS.OpenSettingsPanel(_, addonId)
    local normalizedId = addonId == MANAGER_PANEL_ID and MANAGER_PANEL_ID or NormalizeId(addonId)
    if not normalizedId or (normalizedId ~= MANAGER_PANEL_ID and not panelsById[normalizedId]) then
        return false
    end

    selectedPanelId = normalizedId
    if ui then
        RenderSelectedPanel()
    end
    return true
end

function SETTINGS.OpenLamHub()
    if not RegisterLamHubPanel() then
        return false
    end
    local LAM = GetLam()
    if LAM and SETTINGS.lamPanel and type(LAM.OpenToPanel) == "function" then
        LAM:OpenToPanel(SETTINGS.lamPanel)
        return true
    end
    return false
end

function SETTINGS.RefreshCurrentPanel()
    if ui then
        RenderSelectedPanel()
    end
end

function SETTINGS.Open()
    if not RegisterNativeSettingsPanel() then
        return SETTINGS:OpenLamHub()
    end

    local function SelectWhenReady()
        SelectSettingsNode()
    end

    local gameMenuScene = SCENE_MANAGER and SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene("gameMenuInGame")
    if gameMenuScene and gameMenuScene:GetState() == SCENE_SHOWN then
        SelectWhenReady()
    elseif SCENE_MANAGER and type(SCENE_MANAGER.CallWhen) == "function" then
        SCENE_MANAGER:CallWhen("gameMenuInGame", SCENE_SHOWN, SelectWhenReady)
        SCENE_MANAGER:Show("gameMenuInGame")
    end
    return true
end

function SETTINGS.Initialize()
    if RegisterNativeSettingsPanel() then
        return true
    end
    return RegisterLamHubPanel()
end

function EZOCore.RegisterSettingsPanel(_, addonId, addonPanelId, panelData, options, lamPanel)
    return SETTINGS:RegisterSettingsPanel(addonId, addonPanelId, panelData, options, lamPanel)
end

function EZOCore.GetSettingsPanels()
    return SETTINGS:GetSettingsPanels()
end

function EZOCore.OpenSettingsPanel(_, addonId)
    return SETTINGS:OpenSettingsPanel(addonId)
end

function EZOCore.RefreshSettingsPanel()
    return SETTINGS:RefreshCurrentPanel()
end

function EZOCore.OpenSettings()
    return SETTINGS:Open()
end

function EZOCore.InitializeSettings()
    return SETTINGS:Initialize()
end

EZOCore:RegisterService(SERVICE_NAME, SERVICE_API_VERSION, SETTINGS)
