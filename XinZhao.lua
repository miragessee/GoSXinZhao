if myHero.charName ~= "XinZhao" then return end

-- [ update ]
do
    
    local Version = 2
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "XinZhao.lua",
            Url = "https://raw.githubusercontent.com/miragessee/GoSXinZhao/master/XinZhao.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "miragesxinzhao.version",
            Url = "https://raw.githubusercontent.com/miragessee/GoSXinZhao/master/miragesxinzhao.version"
        }
    }
    
    local function AutoUpdate()
        
        local function DownloadFile(url, path, fileName)
            DownloadFileAsync(url, path .. fileName, function() end)
            while not FileExist(path .. fileName) do end
        end
        
        local function ReadFile(path, fileName)
            local file = io.open(path .. fileName, "r")
            local result = file:read()
            file:close()
            return result
        end
        
        DownloadFile(Files.Version.Url, Files.Version.Path, Files.Version.Name)
        
        local NewVersion = tonumber(ReadFile(Files.Version.Path, Files.Version.Name))
        if NewVersion > Version then
            DownloadFile(Files.Lua.Url, Files.Lua.Path, Files.Lua.Name)
            print(Files.Version.Name .. ": Updated to " .. tostring(NewVersion) .. ". Please Reload with 2x F6")
        else
            print(Files.Version.Name .. ": No Updates Found")
        end
    
    end
    
    AutoUpdate()

end

local _atan = math.atan2
local _min = math.min
local _abs = math.abs
local _sqrt = math.sqrt
local _floor = math.floor
local _max = math.max
local _pow = math.pow
local _huge = math.huge
local _pi = math.pi
local _insert = table.insert
local _contains = table.contains
local _sort = table.sort
local _pairs = pairs
local _find = string.find
local _sub = string.sub
local _len = string.len

local LocalDrawLine = Draw.Line;
local LocalDrawColor = Draw.Color;
local LocalDrawCircle = Draw.Circle;
local LocalDrawCircleMinimap = Draw.CircleMinimap;
local LocalDrawText = Draw.Text;
local LocalControlIsKeyDown = Control.IsKeyDown;
local LocalControlMouseEvent = Control.mouse_event;
local LocalControlSetCursorPos = Control.SetCursorPos;
local LocalControlCastSpell = Control.CastSpell;
local LocalControlKeyUp = Control.KeyUp;
local LocalControlKeyDown = Control.KeyDown;
local LocalControlMove = Control.Move;
local LocalGetTickCount = GetTickCount;
local LocalGamecursorPos = Game.cursorPos;
local LocalGameCanUseSpell = Game.CanUseSpell;
local LocalGameLatency = Game.Latency;
local LocalGameTimer = Game.Timer;
local LocalGameHeroCount = Game.HeroCount;
local LocalGameHero = Game.Hero;
local LocalGameMinionCount = Game.MinionCount;
local LocalGameMinion = Game.Minion;
local LocalGameTurretCount = Game.TurretCount;
local LocalGameTurret = Game.Turret;
local LocalGameWardCount = Game.WardCount;
local LocalGameWard = Game.Ward;
local LocalGameObjectCount = Game.ObjectCount;
local LocalGameObject = Game.Object;
local LocalGameMissileCount = Game.MissileCount;
local LocalGameMissile = Game.Missile;
local LocalGameParticleCount = Game.ParticleCount;
local LocalGameParticle = Game.Particle;
local LocalGameIsChatOpen = Game.IsChatOpen;
local LocalGameIsOnTop = Game.IsOnTop;

local EnemyTraps = {}

local SmiteNames = {'S5_SummonerSmiteDuel', 'S5_SummonerSmitePlayerGanker', 'S5_SummonerSmiteQuick', 'ItemSmiteAoE'};
local mySmiteSlot = 0;

local function GetSmite(smiteSlot)
    local returnVal = 0;
    local spellName = myHero:GetSpellData(smiteSlot).name;
    for i = 1, 5 do
        if spellName == SmiteNames[i] then
            returnVal = smiteSlot
        end
    end
    return returnVal;
end

function GetGameObjects()
    --EnemyHeroes = {}
    print(Game.ObjectCount())
    for i = 1, Game.ObjectCount() do
        local GameObject = Game.Object(i)
        if GameObject.isEnemy then
            if GameObject.charName:match("Cait") then
                if EnemyTraps[GameObject.name] == nil then
                    print(GameObject.isEnemy)
                    print(GameObject.type)
                    print(GameObject.name)
                    print(GameObject.pos)
                    print(EnemyTraps[GameObject.name])
                    Draw.Circle(GameObject.pos, GameObject.boundingRadius, 10, Draw.Color(255, 255, 255, 255))
                    Draw.Text(GameObject.name, 17, GameObject.pos2D.x - 45, GameObject.pos2D.y + 10, Draw.Color(0xFF32CD32))
                    EnemyTraps[GameObject.name] = GameObject.name
                end
            end
        end
    end
    if Game.ObjectCount() == 0 then
        EnemyTraps = {}
    end
--return EnemyHeroes
end

local units = {}

for i = 1, Game.HeroCount() do
    local unit = Game.Hero(i)
    units[i] = {unit = unit, spell = nil}
end

function GetMode()
    if _G.SDK then
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
            return "Harass"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
            return "Clear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
            return "Flee"
        end
    else
        return GOS.GetMode()
    end
end

function IsReady(spell)
    return Game.CanUseSpell(spell) == 0
end

function ValidTarget(target, range)
    range = range and range or math.huge
    return target ~= nil and target.valid and target.visible and not target.dead and target.distance <= range
end

function GetDistance(p1, p2)
    return _sqrt(_pow((p2.x - p1.x), 2) + _pow((p2.y - p1.y), 2) + _pow((p2.z - p1.z), 2))
end

function GetDistance2D(p1, p2)
    return _sqrt(_pow((p2.x - p1.x), 2) + _pow((p2.y - p1.y), 2))
end

local _OnWaypoint = {}
function OnWaypoint(unit)
    if _OnWaypoint[unit.networkID] == nil then _OnWaypoint[unit.networkID] = {pos = unit.posTo, speed = unit.ms, time = LocalGameTimer()} end
    if _OnWaypoint[unit.networkID].pos ~= unit.posTo then
        _OnWaypoint[unit.networkID] = {startPos = unit.pos, pos = unit.posTo, speed = unit.ms, time = LocalGameTimer()}
        DelayAction(function()
            local time = (LocalGameTimer() - _OnWaypoint[unit.networkID].time)
            local speed = GetDistance2D(_OnWaypoint[unit.networkID].startPos, unit.pos) / (LocalGameTimer() - _OnWaypoint[unit.networkID].time)
            if speed > 1250 and time > 0 and unit.posTo == _OnWaypoint[unit.networkID].pos and GetDistance(unit.pos, _OnWaypoint[unit.networkID].pos) > 200 then
                _OnWaypoint[unit.networkID].speed = GetDistance2D(_OnWaypoint[unit.networkID].startPos, unit.pos) / (LocalGameTimer() - _OnWaypoint[unit.networkID].time)
            end
        end, 0.05)
    end
    return _OnWaypoint[unit.networkID]
end

function VectorPointProjectionOnLineSegment(v1, v2, v)
    local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
    local pointLine = {x = ax + rL * (bx - ax), y = ay + rL * (by - ay)}
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or {x = ax + rS * (bx - ax), y = ay + rS * (by - ay)}
    return pointSegment, pointLine, isOnSegment
end

function GetMinionCollision(StartPos, EndPos, Width, Target)
    local Count = 0
    for i = 1, LocalGameMinionCount() do
        local m = LocalGameMinion(i)
        if m and not m.isAlly then
            local w = Width + m.boundingRadius
            local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(StartPos, EndPos, m.pos)
            if isOnSegment and GetDistanceSqr(pointSegment, m.pos) < w ^ 2 and GetDistanceSqr(StartPos, EndPos) > GetDistanceSqr(StartPos, m.pos) then
                Count = Count + 1
            end
        end
    end
    return Count
end

function GetDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx ^ 2 + dz ^ 2
end

function GetEnemyHeroes()
    EnemyHeroes = {}
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isEnemy then
            table.insert(EnemyHeroes, Hero)
        end
    end
    return EnemyHeroes
end

function GetAllyHeroes()
    EnemyHeroes = {}
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isAlly then
            table.insert(EnemyHeroes, Hero)
        end
    end
    return EnemyHeroes
end

function IsUnderTurret(unit)
    for i = 1, Game.TurretCount() do
        local turret = Game.Turret(i);
        if turret and turret.isEnemy and turret.valid and turret.health > 0 then
            if GetDistance(unit, turret.pos) <= 850 then
                return true
            end
        end
    end
    return false
end

function GetDashPos(unit)
    return myHero.pos + (unit.pos - myHero.pos):Normalized() * 500
end

function GetSpellQName()
    return myHero:GetSpellData(_Q).name
end

function GetSpellEName()
    return myHero:GetSpellData(_E).name
end

function GetSpellRName()
    return myHero:GetSpellData(_R).name
end

function IsRecalling()
    for K, Buff in pairs(GetBuffs(myHero)) do
        if Buff.name == "recall" and Buff.duration > 0 then
            return true
        end
    end
    return false
end

function GetPercentHP(unit)
    if type(unit) ~= "userdata" then error("{GetPercentHP}: bad argument #1 (userdata expected, got " .. type(unit) .. ")") end
    return 100 * unit.health / unit.maxHealth
end

function IsImmune(unit)
    if type(unit) ~= "userdata" then error("{IsImmune}: bad argument #1 (userdata expected, got " .. type(unit) .. ")") end
    for i, buff in pairs(GetBuffs(unit)) do
        if (buff.name == "KindredRNoDeathBuff" or buff.name == "UndyingRage") and GetPercentHP(unit) <= 10 then
            return true
        end
        if buff.name == "VladimirSanguinePool" or buff.name == "JudicatorIntervention" then
            return true
        end
    end
    return false
end

local printed = 0

function TestBuff(unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.name == "KaynPassive" and printed == 0 then
            print(buff)
            printed = 1
        end
    end
--print("No buff")
end

function GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 and buff.duration < 2.5 then
            return buff.count
        end
    end
    return 0
end

function GetWTarget()
    for i, enemy in pairs(GetEnemyHeroes()) do
        if GotBuff(enemy, "EvelynnW") == 1 then
            return enemy
        end
    end
end

function ProtobeltDMG()--3152
    local level = myHero.levelData.lvl
    local damage = ({75, 79, 83, 88, 92, 97, 101, 106, 110, 115, 119, 124, 128, 132, 137, 141, 146, 150})[level] + 0.25 * myHero.ap
    return damage
end

function QDmg()
    if myHero:GetSpellData(_Q).level == 0 then
        local Dmg1 = (({20, 25, 30, 35, 40})[1] + 0.40 * myHero.bonusDamage)
        return Dmg1
    else
        local Dmg1 = (({20, 25, 30, 35, 40})[myHero:GetSpellData(_Q).level] + 0.40 * myHero.bonusDamage)
        return Dmg1
    end
end

function WDmg()
    if myHero:GetSpellData(_W).level == 0 then
        local Dmg1 = (({30, 40, 50, 60, 70})[1] + 0.65 * myHero.totalDamage)
        return Dmg1
    else
        local Dmg1 = (({30, 40, 50, 60, 70})[myHero:GetSpellData(_W).level] + 0.65 * myHero.totalDamage)
        return Dmg1
    end
end

function EDmg()
    if myHero:GetSpellData(_E).level == 0 then
        local Dmg1 = (({50, 75, 100, 125, 150})[1] + 0.65 * myHero.ap)
        return Dmg1
    else
        local Dmg1 = (({50, 75, 100, 125, 150})[myHero:GetSpellData(_E).level] + 0.65 * myHero.ap)
        return Dmg1
    end
end

class "XinZhao"

function XinZhao:RDmg(target)
    if myHero:GetSpellData(_R).level == 0 then
        local Dmg1 = (({75, 175, 275})[1] + 1 * myHero.bonusDamage)
        local Bonus = target.health * 0.15
        return Dmg1 + Bonus
    else
        local Dmg1 = (({75, 175, 275})[myHero:GetSpellData(_R).level] + 1 * myHero.bonusDamage)
        local Bonus = target.health * 0.15
        return Dmg1 + Bonus
    end
end

local HeroIcon = "https://www.mobafire.com/images/champion/icon/xin-zhao.png"
local IgniteIcon = "http://pm1.narvii.com/5792/0ce6cda7883a814a1a1e93efa05184543982a1e4_hq.jpg"
local QIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/0/07/Three_Talon_Strike.png"
local WIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/b2/Wind_Becomes_Lightning.png"
local EIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/d/d7/Audacious_Charge.png"
local RIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/c0/Crescent_Guard.png"
local SmiteIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/0/05/Smite.png"
local TiamatIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e3/Tiamat_item.png"
local THydraIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/22/Titanic_Hydra_item.png"
local RHydraIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e8/Ravenous_Hydra_item.png"
local BCIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/44/Bilgewater_Cutlass_item.png"
local HGIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/64/Hextech_Gunblade_item.png"

function TiamatDMG()--3077
    return 100
end

function THydraDMG()--3748
    return 200
end

function GunbladeDMG() --3146
    local level = myHero.levelData.lvl
    local damage = ({175,180,184,189,193,198,203,207,212,216,221,225,230,235,239,244,248,253})[level] + 0.30 * myHero.ap
	return damage
end

local Version, Author, LVersion = "v2", "miragessee", "8.20"

function XinZhao:LoadMenu()
    
    self.Spellx = nil
    
    self.Collision = nil
    
    self.CollisionSpellName = nil
    
    self.XinZhaoMenu = MenuElement({type = MENU, id = "XinZhao", name = "Mirage's XinZhao", leftIcon = HeroIcon})
    
    self.XinZhaoMenu:MenuElement({id = "Harass", name = "Harass", type = MENU})
    self.XinZhaoMenu.Harass:MenuElement({id = "UseW", name = "Use W", value = true, leftIcon = WIcon})
    
    self.XinZhaoMenu:MenuElement({id = "Combo", name = "Combo", type = MENU})
    self.XinZhaoMenu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true, leftIcon = QIcon})
    self.XinZhaoMenu.Combo:MenuElement({id = "UseW", name = "Use W", value = true, leftIcon = WIcon})
    self.XinZhaoMenu.Combo:MenuElement({id = "UseE", name = "Use E", value = true, leftIcon = EIcon})
    self.XinZhaoMenu.Combo:MenuElement({id = "UseR", name = "Use R", value = false, leftIcon = RIcon})
    self.XinZhaoMenu.Combo:MenuElement({id = "UseRl", name = "Use R least health enemy", value = false, leftIcon = RIcon})
    self.XinZhaoMenu.Combo:MenuElement({id = "UseRKS", name = "Use R is killable", value = true, leftIcon = RIcon})
    self.XinZhaoMenu.Combo:MenuElement({id = "UseSmite", name = "Use smite", value = true, leftIcon = SmiteIcon})
    self.XinZhaoMenu.Combo:MenuElement({id = "UseT", name = "Use Tiamat", value = true, leftIcon = TiamatIcon})
    self.XinZhaoMenu.Combo:MenuElement({id = "UseTH", name = "Use Titanic Hydra", value = true, leftIcon = THydraIcon})
    self.XinZhaoMenu.Combo:MenuElement({id = "UseRH", name = "Use Ravenous Hydra", value = true, leftIcon = RHydraIcon})
    self.XinZhaoMenu.Combo:MenuElement({id = "UseBC", name = "Use Bilgewater Cutlass", value = true, leftIcon = BCIcon})
    self.XinZhaoMenu.Combo:MenuElement({id = "UseHG", name = "Use Hextech Gunblade", value = true, leftIcon = HGIcon})
    
    self.XinZhaoMenu:MenuElement({id = "KillSteal", name = "KillSteal", type = MENU})
    self.XinZhaoMenu.KillSteal:MenuElement({id = "UseQ", name = "Use Q", value = true, leftIcon = QIcon})
    self.XinZhaoMenu.KillSteal:MenuElement({id = "UseW", name = "Use W", value = true, leftIcon = EIcon})
    self.XinZhaoMenu.KillSteal:MenuElement({id = "UseE", name = "Use E", value = true, leftIcon = EIcon})
    self.XinZhaoMenu.KillSteal:MenuElement({id = "UseR", name = "Use R", value = true, leftIcon = RIcon})
    self.XinZhaoMenu.KillSteal:MenuElement({id = "UseIgnite", name = "Use Ignite", value = true, leftIcon = IgniteIcon})
    self.XinZhaoMenu.KillSteal:MenuElement({id = "UseT", name = "Use Tiamat", value = true, leftIcon = TiamatIcon})
    self.XinZhaoMenu.KillSteal:MenuElement({id = "UseTH", name = "Use Titanic Hydra", value = true, leftIcon = THydraIcon})
    self.XinZhaoMenu.KillSteal:MenuElement({id = "UseRH", name = "Use Ravenous Hydra", value = true, leftIcon = RHydraIcon})
    self.XinZhaoMenu.KillSteal:MenuElement({id = "UseHG", name = "Use Hextech Gunblade", value = true, leftIcon = HGIcon})
    
    self.XinZhaoMenu:MenuElement({id = "Clear", name = "Clear", type = MENU})
    self.XinZhaoMenu.Clear:MenuElement({id = "UseQ", name = "Use Q", value = true, leftIcon = QIcon})
    self.XinZhaoMenu.Clear:MenuElement({id = "UseW", name = "Use W", value = true, leftIcon = WIcon})
    self.XinZhaoMenu.Clear:MenuElement({id = "UseE", name = "Use E", value = true, leftIcon = EIcon})
    self.XinZhaoMenu.Clear:MenuElement({id = "UseT", name = "Use Tiamat", value = true, leftIcon = TiamatIcon})
    self.XinZhaoMenu.Clear:MenuElement({id = "UseTH", name = "Use Titanic Hydra", value = true, leftIcon = THydraIcon})
    self.XinZhaoMenu.Clear:MenuElement({id = "UseRH", name = "Use Ravenous Hydra", value = true, leftIcon = RHydraIcon})
    
    self.XinZhaoMenu:MenuElement({id = "AutoLevel", name = "AutoLevel", type = MENU})
    self.XinZhaoMenu.AutoLevel:MenuElement({id = "AutoLevel", name = "First E->Q->W then W->Q->E", value = false})
    self.XinZhaoMenu.AutoLevel:MenuElement({id = "AutoLevel2", name = "E->Q->W", value = true})
    
    self.XinZhaoMenu:MenuElement({id = "Drawings", name = "Drawings", type = MENU})
    self.XinZhaoMenu.Drawings:MenuElement({id = "DrawQ", name = "Draw Q Range", value = true})
    self.XinZhaoMenu.Drawings:MenuElement({id = "DrawW", name = "Draw W Range", value = true})
    self.XinZhaoMenu.Drawings:MenuElement({id = "DrawE", name = "Draw W Range", value = true})
    self.XinZhaoMenu.Drawings:MenuElement({id = "DrawR", name = "Draw R Range", value = true})
    self.XinZhaoMenu.Drawings:MenuElement({id = "DrawAA", name = "Draw Killable AAs", value = false})
    self.XinZhaoMenu.Drawings:MenuElement({id = "DrawJng", name = "Draw Jungler Info", value = true})
    self.XinZhaoMenu.Drawings:MenuElement({id = "DrawKS", name = "Draw Killable Skills Info", value = true})
    self.XinZhaoMenu.Drawings:MenuElement({id = "DrawKillable", name = "Draw Killable Enemy Info", value = true})
    self.XinZhaoMenu.Drawings:MenuElement({id = "DrawTF", name = "Draw Team Fight Info", value = true})
    self.XinZhaoMenu.Drawings:MenuElement({id = "DrawHP", name = "Draw Enemy Health Info", value = true})
    self.XinZhaoMenu.Drawings:MenuElement({id = "DrawHPV", name = "Draw Enemy Health % Info", value = 70, min = 0, max = 100})
    
    self.XinZhaoMenu:MenuElement({id = "blank", type = SPACE, name = ""})
    self.XinZhaoMenu:MenuElement({id = "blank", type = SPACE, name = "Script Ver: " .. Version .. " - LoL Ver: " .. LVersion .. ""})
    self.XinZhaoMenu:MenuElement({id = "blank", type = SPACE, name = "by " .. Author .. ""})
end

function XinZhao:LoadSpells()
    XinZhaoQ = {range = 375}
    XinZhaoW = {range = 900, speed = math.huge, delay = 0.5, radius = 45}
    XinZhaoE = {range = 650}
    XinZhaoR = {range = 550}

--["XinZhaoW"]={charName="XinZhao",slot=_W,type="conic",speed=math.huge,range=125,delay=0,angle=180,hitbox=false,aoe=true,cc=false,collision=false},
--["XinZhaoW"]={charName="XinZhao",slot=_W,type="linear",speed=math.huge,range=900,delay=0.5,radius=45,hitbox=true,aoe=true,cc=true,collision=false},
--["XinZhaoR"]={charName="XinZhao",slot=_R,type="circular",speed=math.huge,range=0,delay=0.325,radius=550,hitbox=false,aoe=true,cc=true,collision=false},
end

function XinZhao:__init()
    Item_HK = {}
    self:LoadMenu()
    self:LoadSpells()
    self.SpellsE = {
        ["ThreshRPenta"] = {charName = "Thresh", range = 0, delay = 2.75, radius = 450, collision = false},
        ["VeigarEventHorizon"] = {charName = "Veigar", range = 700, delay = 3.75, radius = 375, collision = false},
        ["YasuoWMovingWall"] = {charName = "Yasuo", range = 400, delay = 4.0, radius = 100, collision = false},
    }
    self.Detected = {}
    Callback.Add("Tick", function()self:Tick() end)
    Callback.Add("Draw", function()self:Draw() end)
end

function XinZhao:Tick()
    if myHero.dead or Game.IsChatOpen() == true or IsRecalling() == true or ExtLibEvade and ExtLibEvade.Evading == true then return end
    
    if self.Detected[1] == nil then
        self.Collision = false
        self.CollisionSpellName = nil
    end
    
    Item_HK[ITEM_1] = HK_ITEM_1
    Item_HK[ITEM_2] = HK_ITEM_2
    Item_HK[ITEM_3] = HK_ITEM_3
    Item_HK[ITEM_4] = HK_ITEM_4
    Item_HK[ITEM_5] = HK_ITEM_5
    Item_HK[ITEM_6] = HK_ITEM_6
    Item_HK[ITEM_7] = HK_ITEM_7
    
    self:Action()
    self:ProcessSpell(GetEnemyHeroes())
    
    if self.XinZhaoMenu.AutoLevel.AutoLevel:Value() then
        local mylevel = myHero.levelData.lvl
        local mylevelpts = myHero.levelData.lvlPts
        
        if mylevelpts > 0 then
            if mylevel == 6 or mylevel == 11 or mylevel == 16 then
                LocalControlKeyDown(HK_LUS)
                LocalControlKeyDown(HK_R)
                LocalControlKeyUp(HK_R)
                LocalControlKeyUp(HK_LUS)
            elseif mylevel == 2 or mylevel == 8 or mylevel == 10 or mylevel == 12 or mylevel == 13 then
                LocalControlKeyDown(HK_LUS)
                LocalControlKeyDown(HK_Q)
                LocalControlKeyUp(HK_Q)
                LocalControlKeyUp(HK_LUS)
            elseif mylevel == 1 or mylevel == 14 or mylevel == 15 or mylevel == 17 or mylevel == 18 then
                LocalControlKeyDown(HK_LUS)
                LocalControlKeyDown(HK_E)
                LocalControlKeyUp(HK_E)
                LocalControlKeyUp(HK_LUS)
            elseif mylevel == 3 or mylevel == 4 or mylevel == 5 or mylevel == 7 or mylevel == 9 then
                LocalControlKeyDown(HK_LUS)
                LocalControlKeyDown(HK_W)
                LocalControlKeyUp(HK_W)
                LocalControlKeyUp(HK_LUS)
            end
        end
    end

    if self.XinZhaoMenu.AutoLevel.AutoLevel2:Value() then
        local mylevel = myHero.levelData.lvl
        local mylevelpts = myHero.levelData.lvlPts
        
        if mylevelpts > 0 then
            if mylevel == 6 or mylevel == 11 or mylevel == 16 then
                LocalControlKeyDown(HK_LUS)
                LocalControlKeyDown(HK_R)
                LocalControlKeyUp(HK_R)
                LocalControlKeyUp(HK_LUS)
            elseif mylevel == 1 or mylevel == 4 or mylevel == 5 or mylevel == 7 or mylevel == 9 then
                LocalControlKeyDown(HK_LUS)
                LocalControlKeyDown(HK_E)
                LocalControlKeyUp(HK_E)
                LocalControlKeyUp(HK_LUS)
            elseif mylevel == 2 or mylevel == 8 or mylevel == 10 or mylevel == 12 or mylevel == 13 then
                LocalControlKeyDown(HK_LUS)
                LocalControlKeyDown(HK_Q)
                LocalControlKeyUp(HK_Q)
                LocalControlKeyUp(HK_LUS)
            elseif mylevel == 3 or mylevel == 14 or mylevel == 15 or mylevel == 17 or mylevel == 18 then
                LocalControlKeyDown(HK_LUS)
                LocalControlKeyDown(HK_W)
                LocalControlKeyUp(HK_W)
                LocalControlKeyUp(HK_LUS)
            end
        end
    end
    
    self:KillSteal()
    
    if GetMode() == "Harass" then
        self:Harass()
    end
    if GetMode() == "Combo" then
        self:Combo()
    end
    if GetMode() == "Clear" then
        self:Clear()
    end
end

function XinZhao:CollisionX(myHeroPos, dangerousPos, unitPos, radius)
    local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(Vector(myHeroPos), Vector(unitPos), Vector(dangerousPos))
    if isOnSegment and GetDistanceSqr(pointSegment, Vector(dangerousPos)) < (myHero.boundingRadius * 2 + radius) ^ 2 then
        return true
    else
        return false
    end
end

function XinZhao:Action()
    for _, spell in pairs(self.Detected) do
        local delay = self.SpellsE[spell.name].delay
        local radius = self.SpellsE[spell.name].radius
        if spell.startTime + delay > Game.Timer() then
            if GetDistance(myHero.pos, spell.endPos) < (radius + myHero.boundingRadius) or GetDistance(spell.source, spell.endPos) < (radius + 100) or self:CollisionX(myHero.pos, spell.endPos, spell.source, radius) then
                --print("Yes")
                self.Collision = true
                self.CollisionSpellName = spell.name
            else
                --print("No")
                self.Collision = false
            end
        else
            table.remove(self.Detected, _)
        end
    end
--print("No")
--self.Collision = false
end

function XinZhao:CalculateEndPos(startPos, placementPos, unitPos, range)
    if range > 0 then
        if GetDistance(unitPos, placementPos) > range then
            local endPos = startPos - Vector(startPos - placementPos):Normalized() * range
            return endPos
        else
            local endPos = placementPos
            return endPos
        end
    else
        local endPos = unitPos
        return endPos
    end
end

function XinZhao:ProcessSpell(units)
    for i = 1, #units do
        local unit = units[i]
        if unit and unit.activeSpell and unit.activeSpell.isChanneling then
            --print(unit.activeSpell.name)
            if self.SpellsE and self.SpellsE[unit.activeSpell.name] then
                local startPos = Vector(unit.activeSpell.startPos)
                local placementPos = Vector(unit.activeSpell.placementPos)
                local unitPos = Vector(unit.pos)
                local sRange = self.SpellsE[unit.activeSpell.name].range
                local endPos = self:CalculateEndPos(startPos, placementPos, unitPos, sRange)
                spell = {source = unitPos, startPos = startPos, endPos = endPos, name = unit.activeSpell.name, startTime = Game.Timer()}
                table.insert(self.Detected, spell)
            end
        end
    end
end

function XinZhao:KillSteal()
    if self.XinZhaoMenu.KillSteal.UseIgnite:Value() then
        for i, enemy in pairs(GetEnemyHeroes()) do
            local IgniteDmg = (55 + 25 * myHero.levelData.lvl)
            if ValidTarget(enemy, 600) and enemy.health + enemy.shieldAD < IgniteDmg then
                if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and IsReady(SUMMONER_1) then
                    Control.CastSpell(HK_SUMMONER_1, enemy)
                elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and IsReady(SUMMONER_2) then
                    Control.CastSpell(HK_SUMMONER_2, enemy)
                end
            end
        end
    end
    if self.XinZhaoMenu.KillSteal.UseT:Value() then
        if GetItemSlot(myHero, 3077) > 0 then
            for i, enemy in pairs(GetEnemyHeroes()) do
                if ValidTarget(enemy, 380) and enemy.health + enemy.shieldAD < TiamatDMG() then
                    if myHero:GetSpellData(GetItemSlot(myHero, 3077)).currentCd == 0 then
                        Control.CastSpell(Item_HK[GetItemSlot(myHero, 3077)], enemy)
                    end
                end
            end
        end
    end
    if self.XinZhaoMenu.KillSteal.UseRH:Value() then
        if GetItemSlot(myHero, 3074) > 0 then
            for i, enemy in pairs(GetEnemyHeroes()) do
                if ValidTarget(enemy, 380) and enemy.health + enemy.shieldAD < TiamatDMG() then
                    if myHero:GetSpellData(GetItemSlot(myHero, 3074)).currentCd == 0 then
                        Control.CastSpell(Item_HK[GetItemSlot(myHero, 3074)], enemy)
                    end
                end
            end
        end
    end
    if self.XinZhaoMenu.KillSteal.UseHG:Value() then
        if GetItemSlot(myHero, 3146) > 0 then
            for i, enemy in pairs(GetEnemyHeroes()) do
                if ValidTarget(enemy, 700) and enemy.health + enemy.shieldAP < GunbladeDMG() then
                    if myHero:GetSpellData(GetItemSlot(myHero, 3146)).currentCd == 0 then
                        Control.CastSpell(Item_HK[GetItemSlot(myHero, 3146)], enemy)
                    end
                end
            end
        end
    end
    if self.XinZhaoMenu.KillSteal.UseTH:Value() then
        if GetItemSlot(myHero, 3748) > 0 then
            for i, enemy in pairs(GetEnemyHeroes()) do
                if ValidTarget(enemy, 380) and enemy.health + enemy.shieldAD < THydraDMG() then
                    if myHero:GetSpellData(GetItemSlot(myHero, 3748)).currentCd == 0 then
                        Control.CastSpell(Item_HK[GetItemSlot(myHero, 3748)], enemy)
                    end
                end
            end
        end
    end
    if self.XinZhaoMenu.KillSteal.UseW:Value() then
        if IsReady(_W) then
            for i, enemy in pairs(GetEnemyHeroes()) do
                if ValidTarget(enemy, XinZhaoW.range) and enemy.health + enemy.shieldAD < WDmg() then
                    LocalControlCastSpell(HK_W, enemy)
                end
            end
        end
    end
    if self.XinZhaoMenu.KillSteal.UseE:Value() then
        if IsReady(_E) then
            for i, enemy in pairs(GetEnemyHeroes()) do
                if ValidTarget(enemy, XinZhaoE.range) and enemy.health + enemy.shieldAP < EDmg() then
                    LocalControlCastSpell(HK_E, enemy)
                end
            end
        end
    end
    if self.XinZhaoMenu.KillSteal.UseQ:Value() then
        if IsReady(_Q) then
            for i, enemy in pairs(GetEnemyHeroes()) do
                if ValidTarget(enemy, XinZhaoQ.range) and enemy.health + enemy.shieldAD < QDmg() then
                    LocalControlCastSpell(HK_Q, enemy)
                end
            end
        end
    end
    if self.XinZhaoMenu.KillSteal.UseR:Value() then
        if IsReady(_R) then
            for i, enemy in pairs(GetEnemyHeroes()) do
                if ValidTarget(enemy, XinZhaoR.range) and enemy.health + enemy.shieldAD < self:RDmg(enemy) then
                    LocalControlCastSpell(HK_R, enemy)
                end
            end
        end
    end
end

function XinZhao:Harass()

    --print(myHero:GetSpellData(_Q).range)
    
    local targetW = GOS:GetTarget(XinZhaoW.range, "AD")
    
    if targetW then
        if not IsImmune(targetW) then
            if self.XinZhaoMenu.Harass.UseW:Value() then
                if IsReady(_W) then
                    if ValidTarget(targetW, XinZhaoW.range) then
                        local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, targetW, XinZhaoW.range, XinZhaoW.delay, XinZhaoW.speed, XinZhaoW.radius, false)
                        if hitChance and hitChance >= 2 then
                            --if GetMinionCollision(myHero.pos, aimPosition, AkaliE.radius) == 0 then
                            self:CastW(targetW, aimPosition)
                        --end
                        end
                    end
                end
            end
        end
    end
end

function XinZhao:CastW(target, EcastPos)
    if LocalGameTimer() - OnWaypoint(target).time > 0.05 and (LocalGameTimer() - OnWaypoint(target).time < 0.125 or LocalGameTimer() - OnWaypoint(target).time > 1.25) then
        if GetDistance(myHero.pos, EcastPos) <= XinZhaoW.range then
            LocalControlCastSpell(HK_W, EcastPos)
        end
    end
end

function XinZhao:Combo()
    
    local targetBC = GOS:GetTarget(550, "AP")
    
    if self.XinZhaoMenu.Combo.UseBC:Value() then
        if GetItemSlot(myHero, 3144) > 0 and ValidTarget(targetBC, 550) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3144)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3144)], targetBC)
            end
        end
    end
    
    local targetHG = GOS:GetTarget(700, "AP")
    
    if self.XinZhaoMenu.Combo.UseHG:Value() then
        if GetItemSlot(myHero, 3146) > 0 and ValidTarget(targetHG, 700) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3146)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3146)], targetHG)
            end
        end
    end

    local targetTiamat = GOS:GetTarget(380, "AD")
    
    if self.XinZhaoMenu.Combo.UseT:Value() then
        if GetItemSlot(myHero, 3077) > 0 and ValidTarget(targetTiamat, 380) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3077)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3077)], targetTiamat)
            end
        end
    end
    
    local targetTHydra = GOS:GetTarget(380, "AD")
    
    if self.XinZhaoMenu.Combo.UseTH:Value() then
        if GetItemSlot(myHero, 3748) > 0 and ValidTarget(targetTHydra, 380) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3748)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3748)], targetTHydra)
            end
        end
    end

    local targetRHydra = GOS:GetTarget(380, "AD")
    
    if self.XinZhaoMenu.Combo.UseRH:Value() then
        if GetItemSlot(myHero, 3074) > 0 and ValidTarget(targetRHydra, 380) then
            if myHero:GetSpellData(GetItemSlot(myHero, 3074)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3074)], targetRHydra)
            end
        end
    end

    local targetE = GOS:GetTarget(XinZhaoE.range, "AP")
    
    if targetE then
        if not IsImmune(targetE) then
            if self.XinZhaoMenu.Combo.UseE:Value() then
                if IsReady(_E) and self.Collision == false then
                    if ValidTarget(targetE, XinZhaoE.range) then
                        LocalControlCastSpell(HK_E, targetE)
                    end
                end
            end
        end
    end
    
    local targetW = GOS:GetTarget(XinZhaoW.range, "AD")
    
    if targetW then
        if not IsImmune(targetW) then
            if self.XinZhaoMenu.Combo.UseW:Value() then
                if IsReady(_W) then
                    if ValidTarget(targetW, XinZhaoW.range) then
                        local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, targetW, XinZhaoW.range, XinZhaoW.delay, XinZhaoW.speed, XinZhaoW.radius, false)
                        if hitChance and hitChance >= 2 then
                            --if GetMinionCollision(myHero.pos, aimPosition, AkaliE.radius) == 0 then
                            self:CastW(targetW, aimPosition)
                        --end
                        end
                    end
                end
            end
        end
    end
    
    local targetQ = GOS:GetTarget(XinZhaoQ.range, "AD")
    
    if targetQ then
        if not IsImmune(targetQ) then
            if self.XinZhaoMenu.Combo.UseW:Value() then
                if IsReady(_Q) then
                    if ValidTarget(targetQ, XinZhaoQ.range) then
                        LocalControlCastSpell(HK_Q, targetQ)
                    end
                end
            end
        end
    end
    
    local targetSmite = GOS:GetTarget(500, "AD")
    
    if self.XinZhaoMenu.Combo.UseSmite:Value() then
        mySmiteSlot = GetSmite(SUMMONER_1);
        if mySmiteSlot == 0 then
            mySmiteSlot = GetSmite(SUMMONER_2);
        end
        
        if ValidTarget(targetSmite, 500) then
            if mySmiteSlot == SUMMONER_1 and IsReady(SUMMONER_1) then
                Control.CastSpell(HK_SUMMONER_1, targetSmite)
            elseif mySmiteSlot == SUMMONER_2 and IsReady(SUMMONER_2) then
                Control.CastSpell(HK_SUMMONER_2, targetSmite)
            end
        end
    end
    
    local targetR = GOS:GetTarget(XinZhaoR.range, "AD")
    
    if self.XinZhaoMenu.Combo.UseR:Value() then
        if IsReady(_R) then
            if ValidTarget(targetR, XinZhaoR.range) then
                LocalControlCastSpell(HK_R, targetR)
            end
        end
    end
    
    if self.XinZhaoMenu.Combo.UseRKS:Value() then
        if IsReady(_R) then
            if ValidTarget(targetR, XinZhaoR.range) and targetR.health + targetR.shieldAD < self:RDmg(targetR) then
                LocalControlCastSpell(HK_R, targetR)
            end
        end
    end
    
    if self.XinZhaoMenu.Combo.UseRl:Value() then
        local minHealth = 50000
        local minHealthEnemy
        
        for i, enemy in pairs(GetEnemyHeroes()) do
            if ValidTarget(enemy, XinZhaoR.range) and enemy.health < minHealth then
                minHealth = enemy.health
                minHealthEnemy = enemy
            end
        end
        
        if minHealthEnemy then
            if not IsImmune(minHealthEnemy) then
                if IsReady(_R) then
                    LocalControlCastSpell(HK_R, minHealthEnemy)
                end
            end
        end
    end
end

function XinZhao:Clear()
    if self.XinZhaoMenu.Clear.UseT:Value() then
        if GetItemSlot(myHero, 3077) > 0 then
            for i = 1, LocalGameMinionCount() do
                local minion = LocalGameMinion(i)
                if minion and minion.isEnemy then
                    if ValidTarget(minion, 380) then
                        if myHero:GetSpellData(GetItemSlot(myHero, 3077)).currentCd == 0 then
                            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3077)], enemy)
                        end
                    end
                end
            end
        end
    end
    if self.XinZhaoMenu.Clear.UseTH:Value() then
        if GetItemSlot(myHero, 3748) > 0 then
            for i = 1, LocalGameMinionCount() do
                local minion = LocalGameMinion(i)
                if minion and minion.isEnemy then
                    if ValidTarget(minion, 380) then
                        if myHero:GetSpellData(GetItemSlot(myHero, 3748)).currentCd == 0 then
                            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3748)], enemy)
                        end
                    end
                end
            end
        end
    end
    if self.XinZhaoMenu.Clear.UseRH:Value() then
        if GetItemSlot(myHero, 3074) > 0 then
            for i = 1, LocalGameMinionCount() do
                local minion = LocalGameMinion(i)
                if minion and minion.isEnemy then
                    if ValidTarget(minion, 380) then
                        if myHero:GetSpellData(GetItemSlot(myHero, 3074)).currentCd == 0 then
                            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3074)], enemy)
                        end
                    end
                end
            end
        end
    end
    if self.XinZhaoMenu.Clear.UseE:Value() then
        for i = 1, LocalGameMinionCount() do
            local minion = LocalGameMinion(i)
            if minion and minion.isEnemy then
                if IsReady(_E) then
                    if ValidTarget(minion, XinZhaoE.range) then
                        LocalControlCastSpell(HK_E, minion)
                    end
                end
            end
        end
    end
    if self.XinZhaoMenu.Clear.UseW:Value() then
        for i = 1, LocalGameMinionCount() do
            local minion = LocalGameMinion(i)
            if minion and minion.isEnemy then
                if IsReady(_W) then
                    if ValidTarget(minion, XinZhaoW.range) then
                        LocalControlCastSpell(HK_W, minion)
                    end
                end
            end
        end
    end
    if self.XinZhaoMenu.Clear.UseQ:Value() then
        for i = 1, LocalGameMinionCount() do
            local minion = LocalGameMinion(i)
            if minion and minion.isEnemy then
                if IsReady(_Q) then
                    if ValidTarget(minion, XinZhaoQ.range) then
                        LocalControlCastSpell(HK_Q, minion)
                    end
                end
            end
        end
    end
end

function XinZhao:Draw()
    if myHero.dead then return end
    if self.XinZhaoMenu.Drawings.DrawQ:Value() then Draw.Circle(myHero.pos, XinZhaoQ.range, 1, Draw.Color(255, 0, 191, 255)) end
    if self.XinZhaoMenu.Drawings.DrawW:Value() then Draw.Circle(myHero.pos, XinZhaoW.range, 1, Draw.Color(255, 65, 105, 225)) end
    if self.XinZhaoMenu.Drawings.DrawE:Value() then Draw.Circle(myHero.pos, XinZhaoE.range, 1, Draw.Color(255, 30, 144, 255)) end
    if self.XinZhaoMenu.Drawings.DrawR:Value() then Draw.Circle(myHero.pos, XinZhaoR.range, 1, Draw.Color(255, 0, 0, 255)) end
    
    for i, enemy in pairs(GetEnemyHeroes()) do
        if self.XinZhaoMenu.Drawings.DrawJng:Value() then
            if enemy:GetSpellData(SUMMONER_1).name == "SummonerSmite" or enemy:GetSpellData(SUMMONER_2).name == "SummonerSmite" then
                Smite = true
            else
                Smite = false
            end
            if Smite then
                if enemy.alive then
                    if ValidTarget(enemy) then
                        if GetDistance(myHero.pos, enemy.pos) > 3000 then
                            Draw.Text("Jungler: Visible", 17, myHero.pos2D.x - 45, myHero.pos2D.y + 10, Draw.Color(0xFF32CD32))
                        else
                            Draw.Text("Jungler: Near", 17, myHero.pos2D.x - 43, myHero.pos2D.y + 10, Draw.Color(0xFFFF0000))
                        end
                    else
                        Draw.Text("Jungler: Invisible", 17, myHero.pos2D.x - 55, myHero.pos2D.y + 10, Draw.Color(0xFFFFD700))
                    end
                else
                    Draw.Text("Jungler: Dead", 17, myHero.pos2D.x - 45, myHero.pos2D.y + 10, Draw.Color(0xFF32CD32))
                end
            end
        end
        if self.XinZhaoMenu.Drawings.DrawAA:Value() then
            if ValidTarget(enemy) then
                AALeft = enemy.health / myHero.totalDamage
                Draw.Text("AA Left: " .. tostring(math.ceil(AALeft)), 17, enemy.pos2D.x - 38, enemy.pos2D.y + 10, Draw.Color(0xFF00BFFF))
            end
        end
        if self.XinZhaoMenu.Drawings.DrawKS:Value() then
            if ValidTarget(enemy) then
                if enemy.health < (WDmg()) then
                    Draw.Text("Killable Skills (W): ", 25, enemy.pos2D.x - 38, enemy.pos2D.y + 10, Draw.Color(0xFFFF0000))
                elseif enemy.health < (EDmg() + WDmg()) then
                    Draw.Text("Killable Skills (E+W): ", 25, enemy.pos2D.x - 38, enemy.pos2D.y + 10, Draw.Color(0xFFFF0000))
                elseif enemy.health < (EDmg() + WDmg() + QDmg()) then
                    Draw.Text("Killable Skills (E+W+Q): ", 25, enemy.pos2D.x - 38, enemy.pos2D.y + 10, Draw.Color(0xFFFF0000))
                elseif enemy.health < (EDmg() + WDmg() + QDmg() + self:RDmg(enemy)) then
                    Draw.Text("Killable Skills (E+W+Q+R): ", 25, enemy.pos2D.x - 38, enemy.pos2D.y + 10, Draw.Color(0xFFFF0000))
                end
            end
        end
        if self.XinZhaoMenu.Drawings.DrawKillable:Value() then
            if ValidTarget(enemy) then
                if enemy.health < (WDmg()) then
                    Draw.Text(tostring(enemy.charName) .. " Killable Skills (W): ", 25, myHero.pos2D.x - 38, myHero.pos2D.y + 10, Draw.Color(0xFFFF0000))
                elseif enemy.health < (EDmg() + WDmg()) then
                    Draw.Text(tostring(enemy.charName) .. " Killable Skills (E+W): ", 25, myHero.pos2D.x - 38, myHero.pos2D.y + 10, Draw.Color(0xFFFF0000))
                elseif enemy.health < (EDmg() + WDmg() + QDmg()) then
                    Draw.Text(tostring(enemy.charName) .. " Killable Skills (E+W+Q): ", 25, myHero.pos2D.x - 38, myHero.pos2D.y + 10, Draw.Color(0xFFFF0000))
                elseif enemy.health < (EDmg() + WDmg() + QDmg() + self:RDmg(enemy)) then
                    Draw.Text(tostring(enemy.charName) .. " Killable Skills (E+W+Q+R): ", 25, myHero.pos2D.x - 38, myHero.pos2D.y + 10, Draw.Color(0xFFFF0000))
                end
            end
        end
        
        if self.XinZhaoMenu.Drawings.DrawHP:Value() then
            if ValidTarget(enemy) then
                local targetHPV = self.XinZhaoMenu.Drawings.DrawHPV:Value()
                if (enemy.health / enemy.maxHealth <= targetHPV / 100) then
                    Draw.Text(tostring(enemy.charName) .. " Health %" .. tostring(targetHPV) .. " Info: ", 25, myHero.pos2D.x - 38, myHero.pos2D.y + 35, Draw.Color(0xFFFF0000))
                end
            end
        end
    end
    
    if self.XinZhaoMenu.Drawings.DrawTF:Value() then
        for i, enemy in pairs(GetEnemyHeroes()) do
            for j, ally in pairs(GetAllyHeroes()) do
                if GetDistance(enemy.pos, ally.pos) < 380 then
                    if ValidTarget(enemy) then
                        Draw.Text(tostring(enemy.charName) .. " Team Fight Info: ", 25, myHero.pos2D.x - 38, myHero.pos2D.y + 60, Draw.Color(0xFFFF0000))
                    end
                end
            end
        end
    end
end

function OnLoad()
    XinZhao()
end

class "HPred"

local _tickFrequency = .2
local _nextTick = LocalGameTimer()
local _reviveLookupTable =
    {
        ["LifeAura.troy"] = 4,
        ["ZileanBase_R_Buf.troy"] = 3,
        ["Aatrox_Base_Passive_Death_Activate"] = 3
    }

local _blinkSpellLookupTable =
    {
        ["EzrealArcaneShift"] = 475,
        ["RiftWalk"] = 500,
        ["EkkoEAttack"] = 0,
        ["AlphaStrike"] = 0,
        ["KatarinaE"] = -255,
        ["KatarinaEDagger"] = {"Katarina_Base_Dagger_Ground_Indicator", "Katarina_Skin01_Dagger_Ground_Indicator", "Katarina_Skin02_Dagger_Ground_Indicator", "Katarina_Skin03_Dagger_Ground_Indicator", "Katarina_Skin04_Dagger_Ground_Indicator", "Katarina_Skin05_Dagger_Ground_Indicator", "Katarina_Skin06_Dagger_Ground_Indicator", "Katarina_Skin07_Dagger_Ground_Indicator", "Katarina_Skin08_Dagger_Ground_Indicator", "Katarina_Skin09_Dagger_Ground_Indicator"},
    }

local _blinkLookupTable =
    {
        "global_ss_flash_02.troy",
        "Lissandra_Base_E_Arrival.troy",
        "LeBlanc_Base_W_return_activation.troy"
    }

local _cachedBlinks = {}
local _cachedRevives = {}
local _cachedTeleports = {}
local _cachedMissiles = {}
local _incomingDamage = {}
local _windwall
local _windwallStartPos
local _windwallWidth

local _OnVision = {}
function HPred:OnVision(unit)
    if unit == nil or type(unit) ~= "userdata" then return end
    if _OnVision[unit.networkID] == nil then _OnVision[unit.networkID] = {visible = unit.visible, tick = LocalGetTickCount(), pos = unit.pos} end
    if _OnVision[unit.networkID].visible == true and not unit.visible then _OnVision[unit.networkID].visible = false _OnVision[unit.networkID].tick = LocalGetTickCount() end
    if _OnVision[unit.networkID].visible == false and unit.visible then _OnVision[unit.networkID].visible = true _OnVision[unit.networkID].tick = LocalGetTickCount()_OnVision[unit.networkID].pos = unit.pos end
    return _OnVision[unit.networkID]
end

function HPred:Tick()
    if _nextTick > LocalGameTimer() then return end
    _nextTick = LocalGameTimer() + _tickFrequency
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t then
            if t.isEnemy then
                HPred:OnVision(t)
            end
        end
    end
    if true then return end
    for _, teleport in _pairs(_cachedTeleports) do
        if teleport and LocalGameTimer() > teleport.expireTime + .5 then
            _cachedTeleports[_] = nil
        end
    end
    HPred:CacheTeleports()
    HPred:CacheParticles()
    for _, revive in _pairs(_cachedRevives) do
        if LocalGameTimer() > revive.expireTime + .5 then
            _cachedRevives[_] = nil
        end
    end
    for _, revive in _pairs(_cachedRevives) do
        if LocalGameTimer() > revive.expireTime + .5 then
            _cachedRevives[_] = nil
        end
    end
    for i = 1, LocalGameParticleCount() do
        local particle = LocalGameParticle(i)
        if particle and not _cachedRevives[particle.networkID] and _reviveLookupTable[particle.name] then
            _cachedRevives[particle.networkID] = {}
            _cachedRevives[particle.networkID]["expireTime"] = LocalGameTimer() + _reviveLookupTable[particle.name]
            local target = HPred:GetHeroByPosition(particle.pos)
            if target.isEnemy then
                _cachedRevives[particle.networkID]["target"] = target
                _cachedRevives[particle.networkID]["pos"] = target.pos
                _cachedRevives[particle.networkID]["isEnemy"] = target.isEnemy
            end
        end
        if particle and not _cachedBlinks[particle.networkID] and _blinkLookupTable[particle.name] then
            _cachedBlinks[particle.networkID] = {}
            _cachedBlinks[particle.networkID]["expireTime"] = LocalGameTimer() + _reviveLookupTable[particle.name]
            local target = HPred:GetHeroByPosition(particle.pos)
            if target.isEnemy then
                _cachedBlinks[particle.networkID]["target"] = target
                _cachedBlinks[particle.networkID]["pos"] = target.pos
                _cachedBlinks[particle.networkID]["isEnemy"] = target.isEnemy
            end
        end
    end

end

function HPred:GetEnemyNexusPosition()
    if myHero.team == 100 then return Vector(14340, 171.977722167969, 14390); else return Vector(396, 182.132507324219, 462); end
end


function HPred:GetGuarenteedTarget(source, range, delay, speed, radius, timingAccuracy, checkCollision)
    local target, aimPosition = self:GetHourglassTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetRevivingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetTeleportingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetImmobileTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
end


function HPred:GetReliableTarget(source, range, delay, speed, radius, timingAccuracy, checkCollision)
    local target, aimPosition = self:GetHourglassTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetRevivingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetTeleportingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetInstantDashTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetDashingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius, midDash)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetImmobileTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetBlinkTarget(source, range, speed, delay, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
end

function HPred:GetLineTargetCount(source, aimPos, delay, speed, width, targetAllies)
    local targetCount = 0
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and self:CanTargetALL(t) and (targetAllies or t.isEnemy) then
            local predictedPos = self:PredictUnitPosition(t, delay + self:GetDistance(source, t.pos) / speed)
            local proj1, pointLine, isOnSegment = self:VectorPointProjectionOnLineSegment(source, aimPos, predictedPos)
            if proj1 and isOnSegment and (self:GetDistanceSqr(predictedPos, proj1) <= (t.boundingRadius + width) * (t.boundingRadius + width)) then
                targetCount = targetCount + 1
            end
        end
    end
    return targetCount
end

function HPred:GetUnreliableTarget(source, range, delay, speed, radius, checkCollision, minimumHitChance, whitelist, isLine)
    local _validTargets = {}
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and self:CanTarget(t, true) and (not whitelist or whitelist[t.charName]) then
            local hitChance, aimPosition = self:GetHitchance(source, t, range, delay, speed, radius, checkCollision, isLine)
            if hitChance >= minimumHitChance then
                _insert(_validTargets, {aimPosition, hitChance, hitChance * 100 + self:CalculateMagicDamage(t, 400)})
            end
        end
    end
    _sort(_validTargets, function(a, b) return a[3] > b[3] end)
    if #_validTargets > 0 then
        return _validTargets[1][2], _validTargets[1][1]
    end
end

function HPred:GetHitchance(source, target, range, delay, speed, radius, checkCollision, isLine)
    if isLine == nil and checkCollision then
        isLine = true
    end
    local hitChance = 1
    local aimPosition = self:PredictUnitPosition(target, delay + self:GetDistance(source, target.pos) / speed)
    local interceptTime = self:GetSpellInterceptTime(source, aimPosition, delay, speed)
    local reactionTime = self:PredictReactionTime(target, .1, isLine)
    if isLine then
        local pathVector = aimPosition - target.pos
        local castVector = (aimPosition - myHero.pos):Normalized()
        if pathVector.x + pathVector.z ~= 0 then
            pathVector = pathVector:Normalized()
            if pathVector:DotProduct(castVector) < -.85 or pathVector:DotProduct(castVector) > .85 then
                if speed > 3000 then
                    reactionTime = reactionTime + .25
                else
                    reactionTime = reactionTime + .15
                end
            end
        end
    end
    Waypoints = self:GetCurrentWayPoints(target)
    if (#Waypoints == 1) then
        HitChance = 2
    end
    if self:isSlowed(target, delay, speed, source) then
        HitChance = 2
    end
    if self:GetDistance(source, target.pos) < 350 then
        HitChance = 2
    end
    local angletemp = Vector(source):AngleBetween(Vector(target.pos), Vector(aimPosition))
    if angletemp > 60 then
        HitChance = 1
    elseif angletemp < 10 then
        HitChance = 2
    end
    if not target.pathing or not target.pathing.hasMovePath then
        hitChancevisionData = 2
        hitChance = 2
    end
    local origin, movementRadius = self:UnitMovementBounds(target, interceptTime, reactionTime)
    if movementRadius - target.boundingRadius <= radius / 2 then
        origin, movementRadius = self:UnitMovementBounds(target, interceptTime, 0)
        if movementRadius - target.boundingRadius <= radius / 2 then
            hitChance = 4
        else
            hitChance = 3
        end
    end
    if target.activeSpell and target.activeSpell.valid then
        if target.activeSpell.startTime + target.activeSpell.windup - LocalGameTimer() >= delay then
            hitChance = 5
        else
            hitChance = 3
        end
    end
    local visionData = HPred:OnVision(target)
    if visionData and visionData.visible == false then
        local hiddenTime = visionData.tick - LocalGetTickCount()
        if hiddenTime < -1000 then
            hitChance = -1
        else
            local targetSpeed = self:GetTargetMS(target)
            local unitPos = target.pos + Vector(target.pos, target.posTo):Normalized() * ((LocalGetTickCount() - visionData.tick) / 1000 * targetSpeed)
            local aimPosition = unitPos + Vector(target.pos, target.posTo):Normalized() * (targetSpeed * (delay + (self:GetDistance(myHero.pos, unitPos) / speed)))
            if self:GetDistance(target.pos, aimPosition) > self:GetDistance(target.pos, target.posTo) then aimPosition = target.posTo end
            hitChance = _min(hitChance, 2)
        end
    end
    if not self:IsInRange(source, aimPosition, range) then
        hitChance = -1
    end
    if hitChance > 0 and checkCollision then
        if self:IsWindwallBlocking(source, aimPosition) then
            hitChance = -1
        elseif self:CheckMinionCollision(source, aimPosition, delay, speed, radius) then
            hitChance = -1
        end
    end
    
    return hitChance, aimPosition
end

function HPred:PredictReactionTime(unit, minimumReactionTime)
    local reactionTime = minimumReactionTime
    if unit.activeSpell and unit.activeSpell.valid then
        local windupRemaining = unit.activeSpell.startTime + unit.activeSpell.windup - LocalGameTimer()
        if windupRemaining > 0 then
            reactionTime = windupRemaining
        end
    end
    return reactionTime
end

function HPred:GetCurrentWayPoints(object)
    local result = {}
    if object.pathing.hasMovePath then
        _insert(result, Vector(object.pos.x, object.pos.y, object.pos.z))
        for i = object.pathing.pathIndex, object.pathing.pathCount do
            path = object:GetPath(i)
            _insert(result, Vector(path.x, path.y, path.z))
        end
    else
        _insert(result, object and Vector(object.pos.x, object.pos.y, object.pos.z) or Vector(object.pos.x, object.pos.y, object.pos.z))
    end
    return result
end

function HPred:GetDashingTarget(source, range, delay, speed, dashThreshold, checkCollision, radius, midDash)
    local target
    local aimPosition
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and t.isEnemy and t.pathing.hasMovePath and t.pathing.isDashing and t.pathing.dashSpeed > 500 then
            local dashEndPosition = t:GetPath(1)
            if self:IsInRange(source, dashEndPosition, range) then
                local dashTimeRemaining = self:GetDistance(t.pos, dashEndPosition) / t.pathing.dashSpeed
                local skillInterceptTime = self:GetSpellInterceptTime(source, dashEndPosition, delay, speed)
                local deltaInterceptTime = skillInterceptTime - dashTimeRemaining
                if deltaInterceptTime > 0 and deltaInterceptTime < dashThreshold and (not checkCollision or not self:CheckMinionCollision(source, dashEndPosition, delay, speed, radius)) then
                    target = t
                    aimPosition = dashEndPosition
                    return target, aimPosition
                end
            end
        end
    end
end

function HPred:GetHourglassTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and t.isEnemy then
            local success, timeRemaining = self:HasBuff(t, "zhonyasringshield")
            if success then
                local spellInterceptTime = self:GetSpellInterceptTime(source, t.pos, delay, speed)
                local deltaInterceptTime = spellInterceptTime - timeRemaining
                if spellInterceptTime > timeRemaining and deltaInterceptTime < timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, interceptPosition, delay, speed, radius)) then
                    target = t
                    aimPosition = t.pos
                    return target, aimPosition
                end
            end
        end
    end
end

function HPred:GetRevivingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for _, revive in _pairs(_cachedRevives) do
        if revive.isEnemy then
            local interceptTime = self:GetSpellInterceptTime(source, revive.pos, delay, speed)
            if interceptTime > revive.expireTime - LocalGameTimer() and interceptTime - revive.expireTime - LocalGameTimer() < timingAccuracy then
                target = revive.target
                aimPosition = revive.pos
                return target, aimPosition
            end
        end
    end
end

function HPred:GetInstantDashTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and t.isEnemy and t.activeSpell and t.activeSpell.valid and _blinkSpellLookupTable[t.activeSpell.name] then
            local windupRemaining = t.activeSpell.startTime + t.activeSpell.windup - LocalGameTimer()
            if windupRemaining > 0 then
                local endPos
                local blinkRange = _blinkSpellLookupTable[t.activeSpell.name]
                if type(blinkRange) == "table" then
                    elseif blinkRange > 0 then
                    endPos = Vector(t.activeSpell.placementPos.x, t.activeSpell.placementPos.y, t.activeSpell.placementPos.z)
                    endPos = t.activeSpell.startPos + (endPos - t.activeSpell.startPos):Normalized() * _min(self:GetDistance(t.activeSpell.startPos, endPos), range)
                    else
                        local blinkTarget = self:GetObjectByHandle(t.activeSpell.target)
                        if blinkTarget then
                            local offsetDirection
                            if blinkRange == 0 then
                                if t.activeSpell.name == "AlphaStrike" then
                                    windupRemaining = windupRemaining + .75
                                end
                                offsetDirection = (blinkTarget.pos - t.pos):Normalized()
                            elseif blinkRange == -1 then
                                offsetDirection = (t.pos - blinkTarget.pos):Normalized()
                            elseif blinkRange == -255 then
                                if radius > 250 then
                                    endPos = blinkTarget.pos
                                end
                            end
                            if offsetDirection then
                                endPos = blinkTarget.pos - offsetDirection * blinkTarget.boundingRadius
                            end
                        end
                end
                local interceptTime = self:GetSpellInterceptTime(source, endPos, delay, speed)
                local deltaInterceptTime = interceptTime - windupRemaining
                if self:IsInRange(source, endPos, range) and deltaInterceptTime < timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, endPos, delay, speed, radius)) then
                    target = t
                    aimPosition = endPos
                    return target, aimPosition
                end
            end
        end
    end
end

function HPred:GetBlinkTarget(source, range, speed, delay, checkCollision, radius)
    local target
    local aimPosition
    for _, particle in _pairs(_cachedBlinks) do
        if particle and self:IsInRange(source, particle.pos, range) then
            local t = particle.target
            local pPos = particle.pos
            if t and t.isEnemy and (not checkCollision or not self:CheckMinionCollision(source, pPos, delay, speed, radius)) then
                target = t
                aimPosition = pPos
                return target, aimPosition
            end
        end
    end
end

function HPred:GetChannelingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t then
            local interceptTime = self:GetSpellInterceptTime(source, t.pos, delay, speed)
            if self:CanTarget(t) and self:IsInRange(source, t.pos, range) and self:IsChannelling(t, interceptTime) and (not checkCollision or not self:CheckMinionCollision(source, t.pos, delay, speed, radius)) then
                target = t
                aimPosition = t.pos
                return target, aimPosition
            end
        end
    end
end

function HPred:GetImmobileTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and self:CanTarget(t) and self:IsInRange(source, t.pos, range) then
            local immobileTime = self:GetImmobileTime(t)
            
            local interceptTime = self:GetSpellInterceptTime(source, t.pos, delay, speed)
            if immobileTime - interceptTime > timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, t.pos, delay, speed, radius)) then
                target = t
                aimPosition = t.pos
                return target, aimPosition
            end
        end
    end
end

function HPred:CacheTeleports()
    for i = 1, LocalGameTurretCount() do
        local turret = LocalGameTurret(i);
        if turret and turret.isEnemy and not _cachedTeleports[turret.networkID] then
            local hasBuff, expiresAt = self:HasBuff(turret, "teleport_target")
            if hasBuff then
                self:RecordTeleport(turret, self:GetTeleportOffset(turret.pos, 223.31), expiresAt)
            end
        end
    end
    for i = 1, LocalGameWardCount() do
        local ward = LocalGameWard(i);
        if ward and ward.isEnemy and not _cachedTeleports[ward.networkID] then
            local hasBuff, expiresAt = self:HasBuff(ward, "teleport_target")
            if hasBuff then
                self:RecordTeleport(ward, self:GetTeleportOffset(ward.pos, 100.01), expiresAt)
            end
        end
    end
    for i = 1, LocalGameMinionCount() do
        local minion = LocalGameMinion(i);
        if minion and minion.isEnemy and not _cachedTeleports[minion.networkID] then
            local hasBuff, expiresAt = self:HasBuff(minion, "teleport_target")
            if hasBuff then
                self:RecordTeleport(minion, self:GetTeleportOffset(minion.pos, 143.25), expiresAt)
            end
        end
    end
end

function HPred:RecordTeleport(target, aimPos, endTime)
    _cachedTeleports[target.networkID] = {}
    _cachedTeleports[target.networkID]["target"] = target
    _cachedTeleports[target.networkID]["aimPos"] = aimPos
    _cachedTeleports[target.networkID]["expireTime"] = endTime + LocalGameTimer()
end


function HPred:CalculateIncomingDamage()
    _incomingDamage = {}
    local currentTime = LocalGameTimer()
    for _, missile in _pairs(_cachedMissiles) do
        if missile then
            local dist = self:GetDistance(missile.data.pos, missile.target.pos)
            if missile.name == "" or currentTime >= missile.timeout or dist < missile.target.boundingRadius then
                _cachedMissiles[_] = nil
            else
                if not _incomingDamage[missile.target.networkID] then
                    _incomingDamage[missile.target.networkID] = missile.damage
                else
                    _incomingDamage[missile.target.networkID] = _incomingDamage[missile.target.networkID] + missile.damage
                end
            end
        end
    end
end

function HPred:GetIncomingDamage(target)
    local damage = 0
    if _incomingDamage[target.networkID] then
        damage = _incomingDamage[target.networkID]
    end
    return damage
end

local _maxCacheRange = 3000
function HPred:CacheParticles()
    if _windwall and _windwall.name == "" then
        _windwall = nil
    end
    
    for i = 1, LocalGameParticleCount() do
        local particle = LocalGameParticle(i)
        if particle and self:IsInRange(particle.pos, myHero.pos, _maxCacheRange) then
            if _find(particle.name, "W_windwall%d") and not _windwall then
                local owner = self:GetObjectByHandle(particle.handle)
                if owner and owner.isEnemy then
                    _windwall = particle
                    _windwallStartPos = Vector(particle.pos.x, particle.pos.y, particle.pos.z)
                    local index = _len(particle.name) - 5
                    local spellLevel = _sub(particle.name, index, index) - 1
                    if type(spellLevel) ~= "number" then
                        spellLevel = 1
                    end
                    _windwallWidth = 150 + spellLevel * 25
                end
            end
        end
    end
end

function HPred:CacheMissiles()
    local currentTime = LocalGameTimer()
    for i = 1, LocalGameMissileCount() do
        local missile = LocalGameMissile(i)
        if missile and not _cachedMissiles[missile.networkID] and missile.missileData then
            if missile.missileData.target and missile.missileData.owner then
                local missileName = missile.missileData.name
                local owner = self:GetObjectByHandle(missile.missileData.owner)
                local target = self:GetObjectByHandle(missile.missileData.target)
                if owner and target and _find(target.type, "Hero") then
                    if (_find(missileName, "BasicAttack") or _find(missileName, "CritAttack")) then
                        _cachedMissiles[missile.networkID] = {}
                        _cachedMissiles[missile.networkID].target = target
                        _cachedMissiles[missile.networkID].data = missile
                        _cachedMissiles[missile.networkID].danger = 1
                        _cachedMissiles[missile.networkID].timeout = currentTime + 1.5
                        local damage = owner.totalDamage
                        if _find(missileName, "CritAttack") then
                            damage = damage * 1.5
                        end
                        _cachedMissiles[missile.networkID].damage = self:CalculatePhysicalDamage(target, damage)
                    end
                end
            end
        end
    end
end

function HPred:CalculatePhysicalDamage(target, damage)
    local targetArmor = target.armor * myHero.armorPenPercent - myHero.armorPen
    local damageReduction = 100 / (100 + targetArmor)
    if targetArmor < 0 then
        damageReduction = 2 - (100 / (100 - targetArmor))
    end
    damage = damage * damageReduction
    return damage
end

function HPred:CalculateMagicDamage(target, damage)
    local targetMR = target.magicResist * myHero.magicPenPercent - myHero.magicPen
    local damageReduction = 100 / (100 + targetMR)
    if targetMR < 0 then
        damageReduction = 2 - (100 / (100 - targetMR))
    end
    damage = damage * damageReduction
    return damage
end


function HPred:GetTeleportingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for _, teleport in _pairs(_cachedTeleports) do
        if teleport.expireTime > LocalGameTimer() and self:IsInRange(source, teleport.aimPos, range) then
            local spellInterceptTime = self:GetSpellInterceptTime(source, teleport.aimPos, delay, speed)
            local teleportRemaining = teleport.expireTime - LocalGameTimer()
            if spellInterceptTime > teleportRemaining and spellInterceptTime - teleportRemaining <= timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, teleport.aimPos, delay, speed, radius)) then
                target = teleport.target
                aimPosition = teleport.aimPos
                return target, aimPosition
            end
        end
    end
end

function HPred:GetTargetMS(target)
    local ms = target.pathing.isDashing and target.pathing.dashSpeed or target.ms
    return ms
end

function HPred:Angle(A, B)
    local deltaPos = A - B
    local angle = _atan(deltaPos.x, deltaPos.z) * 180 / _pi
    if angle < 0 then angle = angle + 360 end
    return angle
end

function HPred:PredictUnitPosition(unit, delay)
    local predictedPosition = unit.pos
    local timeRemaining = delay
    local pathNodes = self:GetPathNodes(unit)
    for i = 1, #pathNodes - 1 do
        local nodeDistance = self:GetDistance(pathNodes[i], pathNodes[i + 1])
        local nodeTraversalTime = nodeDistance / self:GetTargetMS(unit)
        if timeRemaining > nodeTraversalTime then
            timeRemaining = timeRemaining - nodeTraversalTime
            predictedPosition = pathNodes[i + 1]
        else
            local directionVector = (pathNodes[i + 1] - pathNodes[i]):Normalized()
            predictedPosition = pathNodes[i] + directionVector * self:GetTargetMS(unit) * timeRemaining
            break;
        end
    end
    return predictedPosition
end

function HPred:IsChannelling(target, interceptTime)
    if target.activeSpell and target.activeSpell.valid and target.activeSpell.isChanneling then
        return true
    end
end

function HPred:HasBuff(target, buffName, minimumDuration)
    local duration = minimumDuration
    if not minimumDuration then
        duration = 0
    end
    local durationRemaining
    for i = 1, target.buffCount do
        local buff = target:GetBuff(i)
        if buff.duration > duration and buff.name == buffName then
            durationRemaining = buff.duration
            return true, durationRemaining
        end
    end
end

function HPred:GetTeleportOffset(origin, magnitude)
    local teleportOffset = origin + (self:GetEnemyNexusPosition() - origin):Normalized() * magnitude
    return teleportOffset
end

function HPred:GetSpellInterceptTime(startPos, endPos, delay, speed)
    local interceptTime = Game.Latency() / 2000 + delay + self:GetDistance(startPos, endPos) / speed
    return interceptTime
end

function HPred:CanTarget(target, allowInvisible)
    return target.isEnemy and target.alive and target.health > 0 and (allowInvisible or target.visible) and target.isTargetable
end

function HPred:CanTargetALL(target)
    return target.alive and target.health > 0 and target.visible and target.isTargetable
end

function HPred:UnitMovementBounds(unit, delay, reactionTime)
    local startPosition = self:PredictUnitPosition(unit, delay)
    local radius = 0
    local deltaDelay = delay - reactionTime - self:GetImmobileTime(unit)
    if (deltaDelay > 0) then
        radius = self:GetTargetMS(unit) * deltaDelay
    end
    return startPosition, radius
end

function HPred:GetImmobileTime(unit)
    local duration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i);
        if buff.count > 0 and buff.duration > duration and (buff.type == 5 or buff.type == 8 or buff.type == 21 or buff.type == 22 or buff.type == 24 or buff.type == 11 or buff.type == 29 or buff.type == 30 or buff.type == 39) then
            duration = buff.duration
        end
    end
    return duration
end

function HPred:isSlowed(unit, delay, speed, from)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i);
        if from and unit and buff.count > 0 and buff.duration >= (delay + GetDistance(unit.pos, from) / speed) then
            if (buff.type == 10) then
                return true
            end
        end
    end
    return false
end

function HPred:GetSlowedTime(unit)
    local duration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i);
        if buff.count > 0 and buff.duration > duration and buff.type == 10 then
            duration = buff.duration
            return duration
        end
    end
    return duration
end

function HPred:GetPathNodes(unit)
    local nodes = {}
    _insert(nodes, unit.pos)
    if unit.pathing.hasMovePath then
        for i = unit.pathing.pathIndex, unit.pathing.pathCount do
            path = unit:GetPath(i)
            _insert(nodes, path)
        end
    end
    return nodes
end

function HPred:GetObjectByHandle(handle)
    local target
    for i = 1, LocalGameHeroCount() do
        local enemy = LocalGameHero(i)
        if enemy and enemy.handle == handle then
            target = enemy
            return target
        end
    end
    for i = 1, LocalGameMinionCount() do
        local minion = LocalGameMinion(i)
        if minion and minion.handle == handle then
            target = minion
            return target
        end
    end
    for i = 1, LocalGameWardCount() do
        local ward = LocalGameWard(i);
        if ward and ward.handle == handle then
            target = ward
            return target
        end
    end
    for i = 1, LocalGameTurretCount() do
        local turret = LocalGameTurret(i)
        if turret and turret.handle == handle then
            target = turret
            return target
        end
    end
    for i = 1, LocalGameParticleCount() do
        local particle = LocalGameParticle(i)
        if particle and particle.handle == handle then
            target = particle
            return target
        end
    end
end

function HPred:GetHeroByPosition(position)
    local target
    for i = 1, LocalGameHeroCount() do
        local enemy = LocalGameHero(i)
        if enemy and enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then
            target = enemy
            return target
        end
    end
end

function HPred:GetObjectByPosition(position)
    local target
    for i = 1, LocalGameHeroCount() do
        local enemy = LocalGameHero(i)
        if enemy and enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then
            target = enemy
            return target
        end
    end
    for i = 1, LocalGameMinionCount() do
        local enemy = LocalGameMinion(i)
        if enemy and enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then
            target = enemy
            return target
        end
    end
    for i = 1, LocalGameWardCount() do
        local enemy = LocalGameWard(i);
        if enemy and enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then
            target = enemy
            return target
        end
    end
    for i = 1, LocalGameParticleCount() do
        local enemy = LocalGameParticle(i)
        if enemy and enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then
            target = enemy
            return target
        end
    end
end

function HPred:GetEnemyHeroByHandle(handle)
    local target
    for i = 1, LocalGameHeroCount() do
        local enemy = LocalGameHero(i)
        if enemy and enemy.handle == handle then
            target = enemy
            return target
        end
    end
end

function HPred:GetNearestParticleByNames(origin, names)
    local target
    local distance = 999999
    for i = 1, LocalGameParticleCount() do
        local particle = LocalGameParticle(i)
        if particle then
            local d = self:GetDistance(origin, particle.pos)
            if d < distance then
                distance = d
                target = particle
            end
        end
    end
    return target, distance
end

function HPred:GetPathLength(nodes)
    local result = 0
    for i = 1, #nodes - 1 do
        result = result + self:GetDistance(nodes[i], nodes[i + 1])
    end
    return result
end

function HPred:CheckMinionCollision(origin, endPos, delay, speed, radius, frequency)
    if not frequency then
        frequency = radius
    end
    local directionVector = (endPos - origin):Normalized()
    local checkCount = self:GetDistance(origin, endPos) / frequency
    for i = 1, checkCount do
        local checkPosition = origin + directionVector * i * frequency
        local checkDelay = delay + self:GetDistance(origin, checkPosition) / speed
        if self:IsMinionIntersection(checkPosition, radius, checkDelay, radius * 3) then
            return true
        end
    end
    return false
end

function HPred:IsMinionIntersection(location, radius, delay, maxDistance)
    if not maxDistance then
        maxDistance = 500
    end
    for i = 1, LocalGameMinionCount() do
        local minion = LocalGameMinion(i)
        if minion and self:CanTarget(minion) and self:IsInRange(minion.pos, location, maxDistance) then
            local predictedPosition = self:PredictUnitPosition(minion, delay)
            if self:IsInRange(location, predictedPosition, radius + minion.boundingRadius) then
                return true
            end
        end
    end
    return false
end

function HPred:VectorPointProjectionOnLineSegment(v1, v2, v)
    assert(v1 and v2 and v, "VectorPointProjectionOnLineSegment: wrong argument types (3 <Vector> expected)")
    local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
    local pointLine = {x = ax + rL * (bx - ax), y = ay + rL * (by - ay)}
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or {x = ax + rS * (bx - ax), y = ay + rS * (by - ay)}
    return pointSegment, pointLine, isOnSegment
end

function HPred:IsWindwallBlocking(source, target)
    if _windwall then
        local windwallFacing = (_windwallStartPos - _windwall.pos):Normalized()
        return self:DoLineSegmentsIntersect(source, target, _windwall.pos + windwallFacing:Perpendicular() * _windwallWidth, _windwall.pos + windwallFacing:Perpendicular2() * _windwallWidth)
    end
    return false
end

function HPred:DoLineSegmentsIntersect(A, B, C, D)
    local o1 = self:GetOrientation(A, B, C)
    local o2 = self:GetOrientation(A, B, D)
    local o3 = self:GetOrientation(C, D, A)
    local o4 = self:GetOrientation(C, D, B)
    if o1 ~= o2 and o3 ~= o4 then
        return true
    end
    if o1 == 0 and self:IsOnSegment(A, C, B) then return true end
    if o2 == 0 and self:IsOnSegment(A, D, B) then return true end
    if o3 == 0 and self:IsOnSegment(C, A, D) then return true end
    if o4 == 0 and self:IsOnSegment(C, B, D) then return true end
    
    return false
end

function HPred:GetOrientation(A, B, C)
    local val = (B.z - A.z) * (C.x - B.x) -
        (B.x - A.x) * (C.z - B.z)
    if val == 0 then
        return 0
    elseif val > 0 then
        return 1
    else
        return 2
    end

end

function HPred:IsOnSegment(A, B, C)
    return B.x <= _max(A.x, C.x) and
        B.x >= _min(A.x, C.x) and
        B.z <= _max(A.z, C.z) and
        B.z >= _min(A.z, C.z)
end

function HPred:GetSlope(A, B)
    return (B.z - A.z) / (B.x - A.x)
end

function HPred:GetEnemyByName(name)
    local target
    for i = 1, LocalGameHeroCount() do
        local enemy = LocalGameHero(i)
        if enemy and enemy.isEnemy and enemy.charName == name then
            target = enemy
            return target
        end
    end
end

function HPred:IsPointInArc(source, origin, target, angle, range)
    local deltaAngle = _abs(HPred:Angle(origin, target) - HPred:Angle(source, origin))
    if deltaAngle < angle and self:IsInRange(origin, target, range) then
        return true
    end
end

function HPred:GetDistanceSqr(p1, p2)
    if not p1 or not p2 then
        local dInfo = debug.getinfo(2)
        print("Undefined GetDistanceSqr target. Please report. Method: " .. dInfo.name .. "  Line: " .. dInfo.linedefined)
        return _huge
    end
    return (p1.x - p2.x) * (p1.x - p2.x) + ((p1.z or p1.y) - (p2.z or p2.y)) * ((p1.z or p1.y) - (p2.z or p2.y))
end

function HPred:IsInRange(p1, p2, range)
    if not p1 or not p2 then
        local dInfo = debug.getinfo(2)
        print("Undefined IsInRange target. Please report. Method: " .. dInfo.name .. "  Line: " .. dInfo.linedefined)
        return false
    end
    return (p1.x - p2.x) * (p1.x - p2.x) + ((p1.z or p1.y) - (p2.z or p2.y)) * ((p1.z or p1.y) - (p2.z or p2.y)) < range * range
end

function HPred:GetDistance(p1, p2)
    if not p1 or not p2 then
        local dInfo = debug.getinfo(2)
        _print("Undefined GetDistance target. Please report. Method: " .. dInfo.name .. "  Line: " .. dInfo.linedefined)
        return _huge
    end
    return _sqrt(self:GetDistanceSqr(p1, p2))
end
