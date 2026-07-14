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
local INFO_HEADER_TEXTURE = "EsoUI/Art/Miscellaneous/help_icon.dds"
local UNCLASSIFIED_STAGE = "unclassified"
local LIFECYCLE_STAGES = {
    stable = { order = 1, nameKey = "stageStable", tooltipKey = "stageStableTooltip" },
    maintenance = { order = 2, nameKey = "stageMaintenance", tooltipKey = "stageMaintenanceTooltip" },
    archived = { order = 3, nameKey = "stageArchived", tooltipKey = "stageArchivedTooltip" },
    beta = { order = 4, nameKey = "stageBeta", tooltipKey = "stageBetaTooltip" },
    development = { order = 5, nameKey = "stageDevelopment", tooltipKey = "stageDevelopmentTooltip" },
    unclassified = { order = 6, nameKey = "stageUnclassified", tooltipKey = "stageUnclassifiedTooltip" },
}

-- EZO-LIFECYCLE-CATALOG-START
-- Generated from the family ezo-addon.json files by EZOFamilyTools.
local ADDON_LIFECYCLE_CATALOG = {
    ["ezoalerts"] = "beta",
    ["ezoauto"] = "beta",
    ["ezocamsens"] = "archived",
    ["ezochat"] = "development",
    ["ezocombat"] = "development",
    ["ezocursor"] = "beta",
    ["ezocustomsupporticons"] = "development",
    ["ezogroupframes"] = "beta",
    ["ezohud"] = "beta",
    ["ezokeybinds"] = "stable",
    ["ezometter"] = "development",
    ["ezopvp"] = "development",
    ["ezotakingaim"] = "archived",
    ["ezotools"] = "beta",
}
-- EZO-LIFECYCLE-CATALOG-END

local panelsById = {}
local panelOrder = {}
local hubOptions = {}
local pendingAddonStates = {}
local originalAddonStates = {}
local ui
local panelId
local selectedPanelId
local createdSettingsPanel = false
local createdLamHubPanel = false
local controlCounter = 0
local RebuildHubOptions

SETTINGS.reloadRequired = false

local STRINGS = {
    en = {
        installedAddons = "Installed EZO addons",
        installedAddonsTooltip = "Enable or disable installed EZO family addons. Changes require reload.",
        addonSettingsTooltip = "Open settings registered by installed EZO addons through EZOCore.",
        languageHeader = "Language",
        languageHeaderTooltip = "Choose whether EZOCore manages one language for the EZO family "
            .. "or each addon keeps its own selector.",
        language = "EZO family language",
        languageTooltip = "Automatic, English and Spanish lock addon language selectors to the "
            .. "central preference. Let each addon choose re-enables local addon selectors.",
        languageAuto = "Automatic (ESO client)",
        languageEnglish = "English",
        languageSpanish = "Spanish",
        languageAddon = "Let each addon choose",
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
        hubHeader = "EZO settings hub",
        hubHeaderTooltip = "Central access point for EZO family addon settings.",
        addonSettings = "Addon settings",
        stageStable = "Stable",
        stageStableTooltip = "Mature addons intended for regular use.",
        stageMaintenance = "Maintenance",
        stageMaintenanceTooltip = "Mature addons receiving fixes or compatibility updates, "
            .. "with limited active development.",
        stageArchived = "Archived",
        stageArchivedTooltip = "Installed addons retained for access but no longer under active maintenance.",
        stageBeta = "Beta",
        stageBetaTooltip = "Addons ready for broader testing; behavior or settings may still change.",
        stageDevelopment = "Development",
        stageDevelopmentTooltip = "Experimental addons under active construction and intended for controlled testing.",
        stageUnclassified = "Unclassified",
        stageUnclassifiedTooltip = "Installed addons without a valid EZO lifecycle stage. No maturity is inferred.",
    },
    es = {
        installedAddons = "Addons EZO instalados",
        installedAddonsTooltip = "Activa o desactiva addons instalados de la familia EZO. "
            .. "Los cambios requieren recarga.",
        addonSettingsTooltip = "Abre la configuración registrada por addons EZO instalados mediante EZOCore.",
        languageHeader = "Idioma",
        languageHeaderTooltip = "Elige si EZOCore gestiona un idioma para la familia EZO "
            .. "o cada addon mantiene su propio selector.",
        language = "Idioma de la familia EZO",
        languageTooltip = "Automático, inglés y español bloquean los selectores de idioma de los addons "
            .. "a la preferencia central. Dejar que cada addon elija vuelve a habilitarlos.",
        languageAuto = "Automático (cliente ESO)",
        languageEnglish = "Inglés",
        languageSpanish = "Español",
        languageAddon = "Dejar que cada addon elija",
        noOptions = "Este addon todavía no ha registrado opciones.",
        noLam = "LibAddonMenu-2.0 no está disponible. No se pueden dibujar controles de opciones.",
        unsupportedControl = "Control de ajuste no soportado: %s",
        addOnManagerUnavailable = "La API del gestor de addons de ESO no está disponible en este contexto.",
        reloadUi = "Recargar UI",
        reloadUiTooltip = "Aplica cambios de carga/descarga de addons.",
        reloadRequired = "Hace falta recargar para aplicar cambios de carga de addons.",
        coreProtected = "EZOCore no se puede desactivar desde este panel.",
        enabled = "Activado",
        disabled = "Desactivado",
        folder = "Carpeta: %s",
        state = "Estado: %s",
        hubHeader = "Hub de configuración EZO",
        hubHeaderTooltip = "Acceso central a la configuración de los addons de la familia EZO.",
        addonSettings = "Configuración de addons",
        stageStable = "Estables",
        stageStableTooltip = "Addons maduros destinados al uso habitual.",
        stageMaintenance = "Mantenimiento",
        stageMaintenanceTooltip = "Addons maduros que reciben correcciones o compatibilidad, "
            .. "con desarrollo activo limitado.",
        stageArchived = "Archivados",
        stageArchivedTooltip = "Addons instalados que se conservan accesibles, pero ya no tienen mantenimiento activo.",
        stageBeta = "Beta",
        stageBetaTooltip = "Addons preparados para pruebas amplias; su comportamiento o ajustes "
            .. "todavía pueden cambiar.",
        stageDevelopment = "Desarrollo",
        stageDevelopmentTooltip = "Addons experimentales en construcción activa y destinados a pruebas controladas.",
        stageUnclassified = "Sin clasificar",
        stageUnclassifiedTooltip = "Addons instalados sin una fase EZO válida. No se presupone su nivel de madurez.",
    },
}

local function GetLanguage()
    if EZOCore
        and type(EZOCore.GetLanguage) == "function"
        and type(EZOCore.GetConfiguredLanguage) == "function" then
        return EZOCore:GetLanguage()
    end

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

local function NormalizeLifecycleStage(value)
    if not IsNonEmptyString(value) then
        return nil
    end

    local stage = string.lower(value)
    if stage ~= UNCLASSIFIED_STAGE and LIFECYCLE_STAGES[stage] then
        return stage
    end
    return nil
end

local function GetLifecycleStage(entry, addonId)
    if entry and entry.stage and entry.stage ~= UNCLASSIFIED_STAGE then
        return entry.stage
    end

    local normalizedId = NormalizeId(addonId or (entry and entry.addonId))
    return (normalizedId and ADDON_LIFECYCLE_CATALOG[normalizedId]) or UNCLASSIFIED_STAGE
end

local function GetLifecycleDefinition(stage)
    return LIFECYCLE_STAGES[stage] or LIFECYCLE_STAGES[UNCLASSIFIED_STAGE]
end

local function CompareLifecycleEntries(leftStage, leftName, rightStage, rightName)
    local leftDefinition = GetLifecycleDefinition(leftStage)
    local rightDefinition = GetLifecycleDefinition(rightStage)
    if leftDefinition.order ~= rightDefinition.order then
        return leftDefinition.order < rightDefinition.order
    end
    return leftName < rightName
end

local function CreateInfoHeader(name, tooltip)
    return {
        type = "header",
        name = zo_strformat(
            "<<1>> |cB040FF|t26:26:<<2>>:inheritcolor|t|r",
            tostring(name or ""),
            INFO_HEADER_TEXTURE
        ),
        tooltip = tooltip,
    }
end

SETTINGS.CreateInfoHeader = CreateInfoHeader

local function SortPanels()
    table.sort(panelOrder, function(leftId, rightId)
        local left = panelsById[leftId]
        local right = panelsById[rightId]
        local leftName = left and left.sortName or leftId
        local rightName = right and right.sortName or rightId
        return CompareLifecycleEntries(
            GetLifecycleStage(left, leftId),
            leftName,
            GetLifecycleStage(right, rightId),
            rightName)
    end)
end

local function GetLam()
    if type(LibAddonMenu2) == "table" then
        return LibAddonMenu2
    end
    return nil
end

local function ResolveAddOnManager()
    if type(GetAddOnManager) == "function" then
        local ok, manager = pcall(GetAddOnManager)
        if ok and manager then
            return manager
        end
    end
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
    local manager = ResolveAddOnManager()
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

local function GetAddOnRecordId(record)
    if not record then
        return nil
    end

    return NormalizeId(StripMarkup(record.name))
        or NormalizeId(StripMarkup(record.title))
end

local function IsAddOnEnabled(record)
    local addonId = GetAddOnRecordId(record)
    if addonId and pendingAddonStates[addonId] ~= nil then
        return pendingAddonStates[addonId]
    end
    return record and record.enabled == true
end

local function CanSetAddOnEnabled()
    local manager = ResolveAddOnManager()
    return manager and type(manager.SetAddOnEnabled) == "function"
end

local function RefreshReloadButton()
    if not ui or not ui.reloadButton then
        return
    end

    ui.reloadButton:SetText(T("reloadUi"))
    ui.reloadButton:SetEnabled(SETTINGS.reloadRequired == true and type(ReloadUI) == "function")
end

local function RefreshReloadState()
    SETTINGS.reloadRequired = false
    for addonId, enabled in pairs(pendingAddonStates) do
        if originalAddonStates[addonId] ~= nil and originalAddonStates[addonId] ~= enabled then
            SETTINGS.reloadRequired = true
            break
        end
    end
    RefreshReloadButton()
end

local function SetAddOnEnabled(record, enabled)
    local manager = ResolveAddOnManager()
    if not record or not manager or type(manager.SetAddOnEnabled) ~= "function" then
        return false
    end

    local addonId = GetAddOnRecordId(record)
    if addonId and originalAddonStates[addonId] == nil then
        originalAddonStates[addonId] = record.enabled == true
    end

    local ok = pcall(function()
        manager:SetAddOnEnabled(record.index, enabled == true)
    end)
    if ok then
        record.enabled = enabled == true
        if addonId then
            pendingAddonStates[addonId] = record.enabled
            RefreshReloadState()
        else
            SETTINGS.reloadRequired = true
            RefreshReloadButton()
        end
        RebuildHubOptions()
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

local function BuildLanguageOptions()
    return {
        CreateInfoHeader(T("languageHeader"), T("languageHeaderTooltip")),
        {
            type = "dropdown",
            name = T("language"),
            tooltip = T("languageTooltip"),
            choices = {
                T("languageAuto"),
                T("languageEnglish"),
                T("languageSpanish"),
                T("languageAddon"),
            },
            choicesValues = {
                "auto",
                "en",
                "es",
                "addon",
            },
            getFunc = function()
                if EZOCore and type(EZOCore.GetConfiguredLanguage) == "function" then
                    return EZOCore:GetConfiguredLanguage()
                end
                return "auto"
            end,
            setFunc = function(value)
                if EZOCore and type(EZOCore.SetLanguage) == "function" then
                    EZOCore:SetLanguage(value)
                    RebuildHubOptions()
                    SETTINGS:RefreshCurrentPanel()
                end
            end,
        },
    }
end

local function BuildInstalledAddonsOptions()
    local manager = ResolveAddOnManager()
    local count = GetAddOnCount(manager)
    local canSet = CanSetAddOnEnabled()
    local options = {
        CreateInfoHeader(T("installedAddons"), T("installedAddonsTooltip")),
    }

    if not count then
        options[#options + 1] = {
            type = "description",
            text = T("addOnManagerUnavailable"),
        }
        return options
    end

    local addons = GetInstalledEZOAddons()
    table.sort(addons, function(left, right)
        local leftId = GetAddOnRecordId(left)
        local rightId = GetAddOnRecordId(right)
        return CompareLifecycleEntries(
            GetLifecycleStage(leftId and panelsById[leftId], leftId),
            string.lower(StripMarkup(left.title)),
            GetLifecycleStage(rightId and panelsById[rightId], rightId),
            string.lower(StripMarkup(right.title)))
    end)

    local currentStage
    for _, record in ipairs(addons) do
        local title = StripMarkup(record.title)
        local folder = StripMarkup(record.name)
        local state = tostring(record.state or "")
        local addonId = GetAddOnRecordId(record)
        local stage = GetLifecycleStage(addonId and panelsById[addonId], addonId)
        if stage ~= currentStage then
            local definition = GetLifecycleDefinition(stage)
            options[#options + 1] = CreateInfoHeader(T(definition.nameKey), T(definition.tooltipKey))
            currentStage = stage
        end
        local detail = T("folder", folder)
        if state ~= "" then
            detail = detail .. "\n" .. T("state", state)
        end

        options[#options + 1] = {
            type = "checkbox",
            name = title,
            tooltip = detail,
            getFunc = function()
                return IsAddOnEnabled(record)
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

local function BuildCoreOptions()
    return BuildLanguageOptions()
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
        options = BuildCoreOptions,
        sortName = "000 " .. T("installedAddons"),
    }
end

RebuildHubOptions = function()
    for key in pairs(hubOptions) do
        hubOptions[key] = nil
    end

    hubOptions[#hubOptions + 1] = CreateInfoHeader(T("hubHeader"), T("hubHeaderTooltip"))
    local languageOptions = BuildLanguageOptions()
    for index = 1, #languageOptions do
        hubOptions[#hubOptions + 1] = languageOptions[index]
    end

    local addonControls = {
        CreateInfoHeader(T("addonSettings"), T("addonSettingsTooltip")),
    }
    local hasAddonControls = false
    local currentStage
    SortPanels()
    for _, addonId in ipairs(panelOrder) do
        local entry = panelsById[addonId]
        if entry then
            hasAddonControls = true
            local stage = GetLifecycleStage(entry, addonId)
            if stage ~= currentStage then
                local definition = GetLifecycleDefinition(stage)
                addonControls[#addonControls + 1] = CreateInfoHeader(
                    T(definition.nameKey),
                    T(definition.tooltipKey))
                currentStage = stage
            end
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

    if not hasAddonControls then
        addonControls[#addonControls + 1] = {
            type = "description",
            text = T("noOptions"),
        }
    end

    hubOptions[#hubOptions + 1] = {
        type = "submenu",
        name = T("addonSettings"),
        tooltip = T("addonSettingsTooltip"),
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

local function GetMenuDisplayName(rowData)
    local entry = rowData and rowData.entry
    local panelData = entry and entry.panelData or nil
    if panelData then
        return StripMarkup(panelData.displayName or panelData.name or entry.addonId)
    end
    if rowData and rowData.record then
        return StripMarkup(rowData.record.title or rowData.record.name or rowData.addonId)
    end
    return tostring(rowData and rowData.addonId or "")
end

local function BuildMenuRows()
    local rows = {}
    local rowsById = {}

    for _, record in ipairs(GetInstalledEZOAddons()) do
        local addonId = GetAddOnRecordId(record)
        if addonId and not rowsById[addonId] then
            local rowData = {
                addonId = addonId,
                entry = panelsById[addonId],
                record = record,
                stage = GetLifecycleStage(panelsById[addonId], addonId),
            }
            rows[#rows + 1] = rowData
            rowsById[addonId] = rowData
        end
    end

    SortPanels()
    for _, addonId in ipairs(panelOrder) do
        local rowData = rowsById[addonId]
        if rowData then
            rowData.entry = panelsById[addonId]
            rowData.stage = GetLifecycleStage(rowData.entry, addonId)
        else
            rowData = {
                addonId = addonId,
                entry = panelsById[addonId],
                stage = GetLifecycleStage(panelsById[addonId], addonId),
            }
            rows[#rows + 1] = rowData
            rowsById[addonId] = rowData
        end
    end

    table.sort(rows, function(left, right)
        return CompareLifecycleEntries(
            left.stage or UNCLASSIFIED_STAGE,
            string.lower(GetMenuDisplayName(left)),
            right.stage or UNCLASSIFIED_STAGE,
            string.lower(GetMenuDisplayName(right)))
    end)

    table.insert(rows, 1, {
        addonId = MANAGER_PANEL_ID,
        entry = BuildManagerEntry(),
        isCore = true,
    })
    return rows
end

local function CreateMenuGroupHeader(stage)
    local definition = GetLifecycleDefinition(stage)
    controlCounter = controlCounter + 1
    local label = CreateLabel(
        ui.menuChild,
        WINDOW_NAME .. "MenuGroup" .. controlCounter,
        zo_strformat(
            "<<1>> |cB040FF|t26:26:<<2>>:inheritcolor|t|r",
            T(definition.nameKey),
            INFO_HEADER_TEXTURE),
        "ZoFontGameBold")
    label:SetDimensions(270, 30)
    label:SetColor(0.88, 0.84, 0.68, 1)
    label:SetMouseEnabled(true)
    label:SetHandler("OnMouseEnter", function(control)
        if type(ZO_Tooltips_ShowTextTooltip) == "function" then
            ZO_Tooltips_ShowTextTooltip(control, RIGHT, T(definition.tooltipKey))
        end
    end)
    label:SetHandler("OnMouseExit", function()
        if type(ZO_Tooltips_HideTextTooltip) == "function" then
            ZO_Tooltips_HideTextTooltip()
        end
    end)
    return label
end

local function SetMenuLabelColor(label, rowData, hovered)
    if selectedPanelId == rowData.addonId then
        label:SetColor(1, 1, 1, 1)
    elseif hovered and rowData.entry then
        label:SetColor(1, 0.84, 0.45, 1)
    elseif rowData.record and not IsAddOnEnabled(rowData.record) then
        label:SetColor(0.48, 0.48, 0.46, 1)
    elseif not rowData.entry then
        label:SetColor(0.62, 0.62, 0.58, 1)
    else
        label:SetColor(0.78, 0.78, 0.72, 1)
    end
end

local function RebuildMenuList()
    if not ui then
        return
    end

    ClearControls(ui.menuRows)

    local rows = BuildMenuRows()
    local canSet = CanSetAddOnEnabled()

    local previous
    local previousIsHeader = false
    local currentStage
    for _, rowData in ipairs(rows) do
        local currentRow = rowData
        if not currentRow.isCore and currentRow.stage ~= currentStage then
            local header = CreateMenuGroupHeader(currentRow.stage)
            if previous then
                header:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 12)
            else
                header:SetAnchor(TOPLEFT, ui.menuChild, TOPLEFT, 0, 0)
            end
            previous = header
            previousIsHeader = true
            currentStage = currentRow.stage
            ui.menuRows[#ui.menuRows + 1] = header
        end

        controlCounter = controlCounter + 1
        local row = WINDOW_MANAGER:CreateControl(
            WINDOW_NAME .. "MenuRow" .. controlCounter,
            ui.menuChild,
            CT_CONTROL)
        row:SetDimensions(270, 28)

        controlCounter = controlCounter + 1
        local checkbox = WINDOW_MANAGER:CreateControlFromVirtual(
            WINDOW_NAME .. "MenuCheckbox" .. controlCounter,
            row,
            "ZO_CheckButton")
        checkbox:SetAnchor(LEFT, row, LEFT, 0, 0)

        local checked = currentRow.isCore == true
            or (currentRow.record and IsAddOnEnabled(currentRow.record))
            or (currentRow.entry ~= nil and currentRow.record == nil)
        ZO_CheckButton_SetCheckState(checkbox, checked == true)

        local record = currentRow.record
        if currentRow.isCore or not record or not canSet then
            ZO_CheckButton_Disable(checkbox)
        else
            ZO_CheckButton_Enable(checkbox)
            ZO_CheckButton_SetToggleFunction(checkbox, function(control, isChecked)
                if not SetAddOnEnabled(record, isChecked == true) then
                    ZO_CheckButton_SetCheckState(control, not isChecked)
                end
            end)
        end

        controlCounter = controlCounter + 1
        local label = CreateLabel(
            row,
            WINDOW_NAME .. "MenuLabel" .. controlCounter,
            GetMenuDisplayName(currentRow),
            "ZoFontGame")
        label:SetDimensions(230, 28)
        label:SetAnchor(TOPLEFT, row, TOPLEFT, 34, 0)
        label:SetMouseEnabled(currentRow.entry ~= nil)
        if currentRow.entry then
            label:SetHandler("OnMouseUp", function()
                SETTINGS:OpenSettingsPanel(currentRow.addonId)
            end)
            label:SetHandler("OnMouseEnter", function(control)
                SetMenuLabelColor(control, currentRow, true)
            end)
            label:SetHandler("OnMouseExit", function(control)
                SetMenuLabelColor(control, currentRow, false)
            end)
        end
        SetMenuLabelColor(label, currentRow, false)

        if previous then
            row:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, previousIsHeader and 0 or 6)
        else
            row:SetAnchor(TOPLEFT, ui.menuChild, TOPLEFT, 0, 0)
        end
        previous = row
        previousIsHeader = false
        ui.menuRows[#ui.menuRows + 1] = row
    end

    RefreshReloadButton()
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

    local reloadButton = WINDOW_MANAGER:CreateControlFromVirtual(
        WINDOW_NAME .. "ReloadButton",
        root,
        "ZO_DefaultButton")
    reloadButton:SetDimensions(220, 30)
    reloadButton:SetAnchor(TOPLEFT, root, TOPLEFT, 65, 840)
    reloadButton:SetHandler("OnClicked", function()
        if SETTINGS.reloadRequired and type(ReloadUI) == "function" then
            ReloadUI()
        end
    end)

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
        reloadButton = reloadButton,
        menuRows = {},
        panelHosts = {},
        background = { bgLeft, bgRight, underlayLeft, underlayRight, divider },
    }
    RefreshReloadButton()

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
        name = PANEL_DISPLAY_NAME,
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

    local lifecycleStage = NormalizeLifecycleStage(panelData.ezoStage)
    if panelData.ezoStage ~= nil and not lifecycleStage then
        EZOCore:Warn(
            "RegisterSettingsPanel: invalid panelData.ezoStage '%s' (addon '%s')",
            tostring(panelData.ezoStage),
            normalizedId)
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
        stage = lifecycleStage or UNCLASSIFIED_STAGE,
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
            stage = entry.stage,
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
