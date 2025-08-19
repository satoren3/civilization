--[[
-- Created by ARISTOS, April 2018
--
-- Extends the Diplomacy Ribbon lua file to include useful information
-- Non-Cheat Policy: all information included is available in-game
-- EDR only makes the available information readily usable
--]]

-- ===========================================================================
-- Base File to be extended
-- ===========================================================================
include("DiplomacyRibbon");

-- ===========================================================================
-- Cached Base Functions
-- ===========================================================================
BASE_AddLeader = AddLeader;
BASE_OnLeaderClicked = OnLeaderClicked;

-- ===========================================================================
-- Rise & Fall check
-- ===========================================================================
local m_isRiseAndFall:boolean = Modding.IsModActive("1B28771A-C749-434B-9053-D1380C553DE9"); -- Rise & Fall Expansion check
local m_isGatheringStorm:boolean = Modding.IsModActive("4873eb62-8ccc-4574-b784-dda455e74e68"); -- Gathering Storm Expansion check

-- ===========================================================================
-- Customized Variables
-- ===========================================================================
local m_isCTRLDown       :boolean= false;
local EDR_hoveringOverPortrait = false;
local m_uiLeadersByID		:table = {};
local EDR_showAllResources = true;
local isDiplomacyRibbonUpdated : boolean = false;

-- ARISTOS: Left Click Action on Leader Portrait, 
-- override to control behavior of EDR inside DiplomacyActionView
-- ===========================================================================
function OnLeaderLeftClicked(playerID : number )
	if ContextPtr:LookUpControl(".."):GetID() == "DiplomacyActionView" then
		--print("Voiding LEFT click inside DiplomacyActionView...");
		return nil;
	end
	BASE_OnLeaderClicked(playerID);
	--print("Called BASE_OnLeaderClicked!")
end

-- ARISTOS: Right Click Action on Leader Portrait
-- ===========================================================================
function OnLeaderRightClicked(ms_SelectedPlayerID : number )
  if ContextPtr:LookUpControl(".."):GetID() == "DiplomacyActionView" then
		--print("Voiding RIGHT click inside DiplomacyActionView...");
		return nil;
  end
  
  local ms_LocalPlayerID:number = Game.GetLocalPlayer();
  if ms_SelectedPlayerID == ms_LocalPlayerID then
    UpdateLeaders();
	return nil;
  end
  local pPlayer = Players[ms_LocalPlayerID];
  local iPlayerDiploState = pPlayer:GetDiplomaticAI():GetDiplomaticStateIndex(ms_SelectedPlayerID);
  local relationshipHash = GameInfo.DiplomaticStates[iPlayerDiploState].Hash;
  --ARISTOS: to check if Peace Deal is valid
  local bValidAction, tResults = pPlayer:GetDiplomacy():IsDiplomaticActionValid("DIPLOACTION_PROPOSE_PEACE_DEAL", ms_SelectedPlayerID, true); --ARISTOS
  if (not (relationshipHash == DiplomaticStates.WAR)) then
    if (not DealManager.HasPendingDeal(ms_LocalPlayerID, ms_SelectedPlayerID)) then
      DealManager.ClearWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayerID, ms_SelectedPlayerID);
    end
    DiplomacyManager.RequestSession(ms_LocalPlayerID, ms_SelectedPlayerID, "MAKE_DEAL");
  --ARISTOS: To make Right Click on leader go directly to peace deal if Peace Deal is valid
  elseif bValidAction then
    if (not DealManager.HasPendingDeal(ms_LocalPlayerID, ms_SelectedPlayerID)) then
      DealManager.ClearWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayerID, ms_SelectedPlayerID);
      local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, ms_LocalPlayerID, ms_SelectedPlayerID);
      if (pDeal ~= nil) then
        pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, ms_LocalPlayerID);
        if (pDealItem ~= nil) then
          pDealItem:SetSubType(DealAgreementTypes.MAKE_PEACE);
          pDealItem:SetLocked(true);
        end
        -- Validate the deal, this will make sure peace is on both sides of the deal.
        pDeal:Validate();
      end
    end
    DiplomacyManager.RequestSession(ms_LocalPlayerID, ms_SelectedPlayerID, "MAKE_DEAL");
  end
  LuaEvents.QuickDealModeActivate();
end


-- Extended Relationship Tooltip creator
-- Aristos and atggta
function RelationshipGet(nPlayerID :number)
  local tPlayer :table = Players[nPlayerID];
  local nLocalPlayerID :number = Game.GetLocalPlayer();
  local tTooltips :table = tPlayer:GetDiplomaticAI():GetDiplomaticModifiers(nLocalPlayerID);

  if not tTooltips then return ""; end

  local tRelationship :table = {};
  local nRelationshipSum :number = 0;
  local sTextColor :string = "";

  for i, tTooltip in ipairs(tTooltips) do
    local nScore :number = tTooltip.Score;
    local sText :string = tTooltip.Text;

    if(nScore ~= 0) then
      if(nScore > 0) then
        sTextColor = "[COLOR_ModStatusGreen]";
      else
        sTextColor = "[COLOR_Civ6Red]";
      end
      table.insert(tRelationship, {nScore, sTextColor .. nScore .. "[ENDCOLOR] - " .. sText .. "[NEWLINE]"});
      nRelationshipSum = nRelationshipSum + nScore;
    end
  end

  table.sort(
    tRelationship,
    function(a, b)
      return a[1] > b[1];
    end
  );

  local sRelationshipSum :string = "";
  local sRelationship :string = "";
  if(nRelationshipSum >= 0) then
    sRelationshipSum = "[COLOR_ModStatusGreen]";
  else
    sRelationshipSum = "[COLOR_Civ6Red]";
  end
  sRelationshipSum = sRelationshipSum .. nRelationshipSum .. "[ENDCOLOR]"
  for nKey, tValue in pairs(tRelationship) do
    sRelationship = sRelationship .. tValue[2];
  end
  if sRelationship ~= "" then
    sRelationship = Locale.Lookup("LOC_DIPLOMACY_INTEL_RELATIONSHIPS") .. " " .. sRelationshipSum .. "[NEWLINE]" .. sRelationship:sub(1, #sRelationship - #"[NEWLINE]");
  end

  return sRelationship;
end


-- ===========================================================================
-- ARISTOS: To show relationship icon of other civs on hovering mouse over a given leader
function OnLeaderMouseOver(playerID : number )
  EDR_hoveringOverPortrait = true;
  if not isDiplomacyRibbonUpdated then
	--print("EDR updated by first mouse over in " .. ContextPtr:LookUpControl(".."):GetID());
	isDiplomacyRibbonUpdated = true;
	UpdateLeaders();
  end
  local localPlayerID:number = Game.GetLocalPlayer();
  local playerDiplomacy = Players[playerID]:GetDiplomacy();
  if m_isCTRLDown then
    UI.PlaySound("Main_Menu_Mouse_Over");
	if playerID == localPlayerID then
		UpdateLeaders();
		return nil;
	end
    for otherPlayerID, instance in pairs(m_uiLeadersByID) do
      local pPlayer:table = Players[otherPlayerID];
      local pPlayerConfig:table = PlayerConfigurations[otherPlayerID];
      local isHuman:boolean = pPlayerConfig:IsHuman();
      -- Set relationship status (for non-local players)
      local diplomaticAI:table = pPlayer:GetDiplomaticAI();
      local relationshipStateID:number = diplomaticAI:GetDiplomaticStateIndex(playerID);
      if relationshipStateID ~= -1 then
        local relationshipState:table = GameInfo.DiplomaticStates[relationshipStateID];
		local relationshipTooltip:string = Locale.Lookup(relationshipState.Name)
		local isValid:boolean= (isHuman and Relationship.IsValidWithHuman( relationshipState.StateType )) or (not isHuman and Relationship.IsValidWithAI( relationshipState.StateType ));
        -- Always show relationship icon for AIs, only show player triggered states for humans
        if isValid then
          --!! ARISTOS: to extend relationship tooltip to include diplo modifiers!
          --!! Extend it only of the selected player is the local player!
          relationshipTooltip = relationshipTooltip .. (localPlayerID == playerID and ("[NEWLINE][NEWLINE]" .. RelationshipGet(otherPlayerID)) or "");
          -- KWG: This is bad, there is a piece of art that is tied to the order of a database entry.  Please fix!
          instance.Relationship:SetVisState(relationshipStateID);
		end
        --ARISTOS: this shows a ? mark instead of leader portrait if player is unknown to the selected leader
        if (otherPlayerID == playerID or otherPlayerID == localPlayerID) then
          instance.Relationship:SetHide(true);
          instance.Portrait:SetIcon("ICON_"..PlayerConfigurations[otherPlayerID]:GetLeaderTypeName());
        elseif playerDiplomacy:HasMet(otherPlayerID) then
          instance.Relationship:SetToolTipString(relationshipTooltip);
          instance.Relationship:SetHide(not isValid);
          instance.Portrait:SetIcon("ICON_"..PlayerConfigurations[otherPlayerID]:GetLeaderTypeName());
        else
          instance.Portrait:SetIcon("ICON_LEADER_DEFAULT");
          instance.Relationship:LocalizeAndSetToolTip("LOC_DIPLOPANEL_UNMET_PLAYER");
          instance.Relationship:SetHide(true);
         end
      end
      if(playerID == otherPlayerID) then
        instance.YouIndicator:SetHide(false);
      else
        instance.YouIndicator:SetHide(true);
      end
	  instance.TradeIndicator:SetHide(true);
	  instance.PeaceIndicator:SetHide(true);
    end
  end
end


--ARISTOS: little hack for mouse over function
--so that ribbon captures the mouse pointer
function OnLeaderMouseExit()
  EDR_hoveringOverPortrait = false;
end


--ARISTOS: To display key information in leader tooltip inside Diplo Ribbon
function GetExtendedTooltip(playerID:number)
  local govType:string = "";
  local eSelectePlayerGovernment :number = Players[playerID]:GetCulture():GetCurrentGovernment();
  if eSelectePlayerGovernment ~= -1 then
    govType = Locale.Lookup(GameInfo.Governments[eSelectePlayerGovernment].Name);
  else
    govType = Locale.Lookup("LOC_GOVERNMENT_ANARCHY_NAME" );
  end
  local cities = Players[playerID]:GetCities();
  local numCities = 0;
  local ERD_Total_Population = 0;
  for i,city in cities:Members() do
	ERD_Total_Population = ERD_Total_Population + city:GetPopulation();
    numCities = numCities + 1;
  end
  --ARISTOS: Add gold to tooltip
  local playerTreasury:table	= Players[playerID]:GetTreasury();
  local goldBalance	:number = math.floor(playerTreasury:GetGoldBalance());
  local goldYield	:number = math.floor((playerTreasury:GetGoldYield() - playerTreasury:GetTotalMaintenance()));
  
  -- Grievances
  local iGrievancesOnThem = m_isGatheringStorm and Players[Game.GetLocalPlayer()]:GetDiplomacy():GetGrievancesAgainst(playerID) or 0;
  local relationshipString:string = "";
  if m_isGatheringStorm then
	  if iGrievancesOnThem > 0 then
			relationshipString = "[COLOR_ModStatusGreen]"..Locale.Lookup("LOC_DIPLOMACY_GRIEVANCES_WITH_THEM_SIMPLE", iGrievancesOnThem).. "[ENDCOLOR]";
	  elseif iGrievancesOnThem < 0 then
			relationshipString = "[COLOR_Civ6Red]"..Locale.Lookup("LOC_DIPLOMACY_GRIEVANCES_WITH_US_SIMPLE", -iGrievancesOnThem).. "[ENDCOLOR]";
	  else
			relationshipString = "";
	  end
  end
  
  --Eras
  local sEras = "";
  if (m_isRiseAndFall or m_isGatheringStorm) then
	  local pGameEras:table = Game.GetEras();
	  if pGameEras:HasHeroicGoldenAge(playerID) then
		sEras = " ("..Locale.Lookup("LOC_ERA_PROGRESS_HEROIC_AGE").." [ICON_GLORY_SUPER_GOLDEN_AGE])";
	  elseif pGameEras:HasGoldenAge(playerID) then
		sEras = " ("..Locale.Lookup("LOC_ERA_PROGRESS_GOLDEN_AGE").." [ICON_GLORY_GOLDEN_AGE])";
	  elseif pGameEras:HasDarkAge(playerID) then
		sEras = " ("..Locale.Lookup("LOC_ERA_PROGRESS_DARK_AGE").." [ICON_GLORY_DARK_AGE])";
	  else
		sEras = " ("..Locale.Lookup("LOC_ERA_PROGRESS_NORMAL_AGE").." [ICON_GLORY_NORMAL_AGE])";
	  end
  end
  
  --Intel Access level
  local iAccessLevel = Players[Game.GetLocalPlayer()]:GetDiplomacy():GetVisibilityOn(playerID);

  -- Stats
  local civData:string = sEras
	.."[NEWLINE]"..Locale.Lookup("LOC_DIPLOMACY_INTEL_GOVERNMENT").." "..Locale.ToUpper(govType)
	..(Game.GetLocalPlayer()==playerID and "" or "[NEWLINE]"..Locale.Lookup("LOC_DIPLOMACY_OVERVIEW_ACCESS_LEVEL")..": "..Locale.ToUpper(GameInfo.Visibilities[iAccessLevel].Name))
    .."[NEWLINE]"..Locale.Lookup("LOC_PEDIA_CONCEPTS_PAGEGROUP_CITIES_NAME").. ": " .. "[COLOR_FLOAT_PRODUCTION]" .. numCities .. "[ENDCOLOR] [ICON_Housing]    " 
		.. Locale.Lookup("LOC_DEAL_CITY_POPULATION_TOOLTIP", ERD_Total_Population) .. " [ICON_Citizen]"
	..((m_isGatheringStorm and playerID ~= Game.GetLocalPlayer() and iGrievancesOnThem ~= 0) and "[NEWLINE]"..relationshipString or "")
	.."[NEWLINE]-----------------------------------------------"
    .."[NEWLINE][ICON_Capital] "..Locale.Lookup("LOC_WORLD_RANKINGS_OVERVIEW_DOMINATION_SCORE", Players[playerID]:GetScore())
	..(m_isGatheringStorm and "[NEWLINE] [ICON_Favor]  "..Locale.Lookup("LOC_DIPLOMATIC_FAVOR_NAME") .. ": [COLOR_Red]" .. Players[playerID]:GetFavor().."[ENDCOLOR]" or "")
	.."[NEWLINE][ICON_Gold] "..Locale.Lookup("LOC_YIELD_GOLD_NAME")..": "..goldBalance.."   ( " .. "[COLOR_GoldMetalDark]" .. (goldYield>0 and "+" or "") .. (goldYield>0 and goldYield or "-?") .. "[ENDCOLOR]  )"
    .."[NEWLINE]"..Locale.Lookup("LOC_WORLD_RANKINGS_OVERVIEW_SCIENCE_SCIENCE_RATE", "[COLOR_FLOAT_SCIENCE]" .. Round(Players[playerID]:GetTechs():GetScienceYield(),1) .. "[ENDCOLOR]")
    .."[NEWLINE][ICON_Science] "..Locale.Lookup("LOC_WORLD_RANKINGS_OVERVIEW_SCIENCE_NUM_TECHS", "[COLOR_Blue]" .. Players[playerID]:GetStats():GetNumTechsResearched() .. "[ENDCOLOR]")
    .."[NEWLINE]"..Locale.Lookup("LOC_WORLD_RANKINGS_OVERVIEW_CULTURE_CULTURE_RATE", "[COLOR_FLOAT_CULTURE]" .. Round(Players[playerID]:GetCulture():GetCultureYield(),1) .. "[ENDCOLOR]")
    .."[NEWLINE]"..Locale.Lookup("LOC_WORLD_RANKINGS_OVERVIEW_CULTURE_TOURISM_RATE", "[COLOR_Tourism]" .. Round(Players[playerID]:GetStats():GetTourism(),1) .. "[ENDCOLOR]")
    .."[NEWLINE]"..Locale.Lookup("LOC_WORLD_RANKINGS_OVERVIEW_RELIGION_FAITH_RATE", Round(Players[playerID]:GetReligion():GetFaithYield(),1))
    .."[NEWLINE][ICON_Strength] "..Locale.Lookup("LOC_WORLD_RANKINGS_OVERVIEW_DOMINATION_MILITARY_STRENGTH", "[COLOR_FLOAT_MILITARY]" .. Players[playerID]:GetStats():GetMilitaryStrengthWithoutTreasury() .. "[ENDCOLOR]")
	;
	
  local canTrade, tooltip = CheckTrades(playerID, 0, EDR_showAllResources);
  civData = civData .. (canTrade == true and "[NEWLINE]-----------------------------------------------" or "") .. tooltip;
  
  local deals: string = AddTradeDeals(playerID);
  if deals ~= nil then
	civData = civData .. deals;
  end

  return civData;
end

function CheckTrades(playerID: number, minAmount: number, showAll: boolean)
	local tooltip = "";
	local canTrade = false;
	
	local MAX_WIDTH = 4;
	local pLuxuries = "";
	local pStrategics = "";
	local pLuxNum = 0;
	local pStratNum = 0;
	
	local pForDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, Game.GetLocalPlayer(), playerID);
	local pPlayerResources = DealManager.GetPossibleDealItems(playerID, Game.GetLocalPlayer(), DealItemTypes.RESOURCES, pForDeal);
	local pLocalPlayerResources = Players[Game.GetLocalPlayer()]:GetResources();
	
	if (pPlayerResources ~= nil) then
		for i,entry in ipairs(pPlayerResources) do 
			local resource = GameInfo.Resources[entry.ForType];
			local amount = entry.MaxAmount;
			local amountString = (showAll and playerID ~= Game.GetLocalPlayer()) and 
								(pLocalPlayerResources:HasResource(entry.ForType) and "[COLOR_ModStatusGreenCS]" .. amount .. "[ENDCOLOR]" or "[COLOR_ModStatusRedCS]" .. amount .. "[ENDCOLOR]") or
								 amount;
			local showResource = showAll or not pLocalPlayerResources:HasResource(entry.ForType);
			if (resource.ResourceClassType == "RESOURCECLASS_STRATEGIC") then
				if (amount > minAmount and showResource) then
					pStrategics = ((pStratNum - MAX_WIDTH)%(MAX_WIDTH) == 0) and (pStrategics .. "[NEWLINE]" .. "[ICON_"..resource.ResourceType.."]".. amountString .. "  ") 
					or (pStrategics .. "[ICON_"..resource.ResourceType.."]".. amountString .. "  ");
					pStratNum = pStratNum + 1;
				end
			elseif (resource.ResourceClassType == "RESOURCECLASS_LUXURY") then
				if (amount > minAmount and showResource) then
					pLuxuries = ((pLuxNum - MAX_WIDTH)%(MAX_WIDTH) == 0) and (pLuxuries .. "[NEWLINE]" .. "[ICON_"..resource.ResourceType.."]" .. amountString .. "  ") 
					or (pLuxuries .. "[ICON_"..resource.ResourceType.."]" .. amountString .. "  ");
					pLuxNum = pLuxNum + 1;
				end
			end
		end
	end
	
	if (minAmount > 0) then
		tooltip = Locale.Lookup("LOC_HUD_REPORTS_TAB_RESOURCES") .. " (> " .. minAmount .. ") :";
	end
	
	tooltip = pStratNum > 0 and (tooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_HUD_REPORTS_STRATEGICS") .. ":" .. pStrategics) or (tooltip .. "");
	tooltip = pLuxNum > 0  and (tooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_HUD_REPORTS_LUXURIES") .. ":" .. pLuxuries) or (tooltip .. "");
	
	if (pStratNum > 0 or pLuxNum > 0) then
		canTrade = true;
	else
		canTrade = false;
	end
	
	--print(tostring(canTrade),tooltip,pStratNum,pLuxNum);
	return canTrade, tooltip;
	
end

-- ===========================================================================
--	ARISTOS: to add existing deals to the end of the extended tooltip
-- ===========================================================================
function AddTradeDeals(playerID: number)
local localPlayerID:number = Game.GetLocalPlayer();
local currentGameTurn = Game.GetCurrentGameTurn();
local tradeDealsTooltip: string;
local outgoingDeals: string;
local incomingDeals: string;
if  playerID ~= localPlayerID then			
	
	local pPlayerConfig	:table = PlayerConfigurations[otherID];
	local pDeals		:table = DealManager.GetPlayerDeals(localPlayerID, playerID);
	
	if pDeals ~= nil then
		
		for i,pDeal in ipairs(pDeals) do
			outgoingDeals = "";
			incomingDeals = "";
			local remainingTurns: number;
			--if pDeal:IsValid() then  --ARISTOS: BUGGED as Hell!!!! Shame on you Firaxis...
				
				-- Add outgoing gold deals
				local pOutgoingDeal :table	= pDeal:FindItemsByType(DealItemTypes.GOLD, DealItemSubTypes.NONE, playerID);
				if pOutgoingDeal ~= nil then
					for i,pDealItem in ipairs(pOutgoingDeal) do
						local duration		:number = pDealItem:GetDuration();
						remainingTurns = duration - (currentGameTurn - pDealItem:GetEnactedTurn());
						if duration ~= 0 then
							local goldAmount :number = pDealItem:GetAmount();
							outgoingDeals = outgoingDeals .. " " .. goldAmount .. "[ICON_Gold]";
						end
					end
				end

				-- Add outgoing resource deals
				pOutgoingDeal = pDeal:FindItemsByType(DealItemTypes.RESOURCES, DealItemSubTypes.NONE, playerID);
				if pOutgoingDeal ~= nil then
					for i,pDealItem in ipairs(pOutgoingDeal) do
						local duration		:number = pDealItem:GetDuration();
						remainingTurns = duration - (currentGameTurn - pDealItem:GetEnactedTurn());
						if duration ~= 0 then
							local amount		:number = pDealItem:GetAmount();
							local resourceType	:number = pDealItem:GetValueType();
							outgoingDeals = outgoingDeals .. " " .. amount .. "[ICON_"..GameInfo.Resources[resourceType].ResourceType.."]";
						end
					end
				end
				
				-- Add incoming gold deals
				local pIncomingDeal :table = pDeal:FindItemsByType(DealItemTypes.GOLD, DealItemSubTypes.NONE, localPlayerID);
				if pIncomingDeal ~= nil then
					for i,pDealItem in ipairs(pIncomingDeal) do
						local duration		:number = pDealItem:GetDuration();
						remainingTurns = duration - (currentGameTurn - pDealItem:GetEnactedTurn());
						if duration ~= 0 then
							local goldAmount :number = pDealItem:GetAmount()
							incomingDeals = incomingDeals .. " " .. goldAmount .. "[ICON_Gold]";
						end
					end
				end

				-- Add incoming resource deals
				pIncomingDeal = pDeal:FindItemsByType(DealItemTypes.RESOURCES, DealItemSubTypes.NONE, localPlayerID);
				if pIncomingDeal ~= nil then
					for i,pDealItem in ipairs(pIncomingDeal) do
						local duration		:number = pDealItem:GetDuration();
						if duration ~= 0 then
							local amount		:number = pDealItem:GetAmount();
							local resourceType	:number = pDealItem:GetValueType();
							remainingTurns = duration - (currentGameTurn - pDealItem:GetEnactedTurn());
							incomingDeals = incomingDeals .. " " .. amount .. "[ICON_"..GameInfo.Resources[resourceType].ResourceType.."]";
						end
					end
				end
				if remainingTurns ~= nil then
					tradeDealsTooltip = tradeDealsTooltip == nil and "[NEWLINE]-----------------------------------------------[NEWLINE]" or tradeDealsTooltip .. "[NEWLINE]"
					tradeDealsTooltip = tradeDealsTooltip .. (incomingDeals:len()>0 and incomingDeals or "          ") .. " <<| " .. remainingTurns .. "[ICON_TURN] |>> " .. outgoingDeals;
				end
			--end	
		end							
	end

end

return tradeDealsTooltip;

end

-- ===========================================================================
--	Auxiliary Functions
-- ===========================================================================
function Round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    if num >= 0 then return math.floor(num * mult + 0.5) / mult
    else return math.ceil(num * mult - 0.5) / mult end
end

-- Override ADDLEADER function for both vanilla and R&F
-- ===========================================================================
function AddLeader(iconName : string, playerID : number, kProps: table)
	local leaderIcon, instance = BASE_AddLeader(iconName, playerID, kProps);
	m_uiLeadersByID[playerID] = instance;
	
	local localPlayerID:number = Game.GetLocalPlayer();
	if localPlayerID == -1 or localPlayerID == 1000 then
		return;
	end
	
	local m_baseRelationshipTooltip;
	local localPlayerDiplomacy:table = Players[Game.GetLocalPlayer()]:GetDiplomacy();

	if (m_isRiseAndFall or m_isGatheringStorm) then
		-- Update relationship pip tool with details about our alliance if we're in one
		if localPlayerDiplomacy then
			local allianceType = localPlayerDiplomacy:GetAllianceType(playerID);
			if allianceType ~= -1 then
				local allianceName = Locale.Lookup(GameInfo.Alliances[allianceType].Name);
				local allianceLevel = localPlayerDiplomacy:GetAllianceLevel(playerID);
				m_baseRelationshipTooltip = Locale.Lookup("LOC_DIPLOMACY_ALLIANCE_FLAG_TT", allianceName, allianceLevel)
					.."[NEWLINE]" ..Locale.Lookup("LOC_DIPLOACTION_EXPIRES_IN_X_TURNS", localPlayerDiplomacy:GetAllianceTurnsUntilExpiration(playerID));
			end
		end
	end
	
	local pPlayer:table = Players[playerID];	  
	local pPlayerConfig:table = PlayerConfigurations[playerID];
	local isHuman:boolean = pPlayerConfig:IsHuman();
	
	leaderIcon:RegisterCallback(Mouse.eLClick, function() OnLeaderLeftClicked(playerID); end);
	leaderIcon:RegisterCallback(Mouse.eRClick, function() OnLeaderRightClicked(playerID); end);
	leaderIcon:RegisterCallback( Mouse.eMouseEnter, function() OnLeaderMouseOver(playerID); end ); 
	leaderIcon:RegisterCallback( Mouse.eMouseExit, function() OnLeaderMouseExit(); end );
	leaderIcon:RegisterCallback( Mouse.eMClick, function() m_isCTRLDown = not m_isCTRLDown; OnLeaderMouseOver(playerID); end ); 

	local bShowRelationshipIcon:boolean = false;
	--local localPlayerID:number = Game.GetLocalPlayer();

	if(playerID == localPlayerID) then
		instance.YouIndicator:SetHide(false);
	else
		-- Set relationship status (for non-local players)
		local diplomaticAI:table = pPlayer:GetDiplomaticAI();
		local relationshipStateID:number = diplomaticAI:GetDiplomaticStateIndex(localPlayerID);
		if relationshipStateID ~= -1 then
			local relationshipState:table = GameInfo.DiplomaticStates[relationshipStateID];
			
			-- Remaining turns for Friendship or Denouncement
			local iRemainingTurns;
			local sTurns = "";
			if (relationshipState.StateType == "DIPLO_STATE_DENOUNCED") then
				local iOurDenounceTurn = localPlayerDiplomacy:GetDenounceTurn(playerID);
				local iTheirDenounceTurn = Players[playerID]:GetDiplomacy():GetDenounceTurn(localPlayerID);
				local iPlayerOrderAdjustment = 0;
				if (iTheirDenounceTurn >= iOurDenounceTurn) then
					if (playerID > localPlayerID) then
						iPlayerOrderAdjustment = 1;
					end
				else
					if (localPlayerID > playerID) then
						iPlayerOrderAdjustment = 1;
					end
				end
				if (iOurDenounceTurn >= iTheirDenounceTurn) then  
					iRemainingTurns = 1 + iOurDenounceTurn + Game.GetGameDiplomacy():GetDenounceTimeLimit() - Game.GetCurrentGameTurn() + iPlayerOrderAdjustment;
				else
					iRemainingTurns = 1 + iTheirDenounceTurn + Game.GetGameDiplomacy():GetDenounceTimeLimit() - Game.GetCurrentGameTurn() + iPlayerOrderAdjustment;
				end
			elseif (relationshipState.StateType == "DIPLO_STATE_DECLARED_FRIEND") then
				local iFriendshipTurn = localPlayerDiplomacy:GetDeclaredFriendshipTurn(playerID);
				iRemainingTurns = iFriendshipTurn + Game.GetGameDiplomacy():GetDenounceTimeLimit() - Game.GetCurrentGameTurn();
			end
			sTurns = iRemainingTurns ~= nil and "[NEWLINE]" .. Locale.Lookup("LOC_DIPLOACTION_EXPIRES_IN_X_TURNS", iRemainingTurns) or "";
			local isValid:boolean= (isHuman and Relationship.IsValidWithHuman( relationshipState.StateType )) or (not isHuman and Relationship.IsValidWithAI( relationshipState.StateType ));
			-- Always show relationship icon for AIs, only show player triggered states for humans
			if isValid or relationshipState.Hash == DiplomaticStates.NEUTRAL then
				--!! ARISTOS: to extend relationship tooltip to include diplo modifiers!
				local extendedRelationshipTooltip:string = (m_baseRelationshipTooltip ~= nil and m_baseRelationshipTooltip or Locale.Lookup(relationshipState.Name)..sTurns)
				.. "[NEWLINE][NEWLINE]" .. RelationshipGet(playerID);
				instance.Relationship:SetVisState(relationshipStateID);
				instance.Relationship:SetToolTipString(extendedRelationshipTooltip);
				bShowRelationshipIcon = true;
			end
		end
		instance.YouIndicator:SetHide(true);
	end
	
	instance.Relationship:SetHide(not bShowRelationshipIcon);
		
	local relationshipHash = GameInfo.DiplomaticStates[Players[localPlayerID]:GetDiplomaticAI():GetDiplomaticStateIndex(playerID)].Hash;
	local canMakePeace, tResults = Players[localPlayerID]:GetDiplomacy():IsDiplomaticActionValid("DIPLOACTION_PROPOSE_PEACE_DEAL", playerID, true);
	
	local canTrade, tooltip = CheckTrades(playerID, 1, false);
	
	instance.TradeIndicator:SetHide(not canTrade or (relationshipHash == DiplomaticStates.WAR));
	instance.PeaceIndicator:SetHide(not canMakePeace);
	instance.TradeIndicator:SetToolTipString(tooltip);
	instance.PeaceIndicator:SetToolTipString(Locale.Lookup("LOC_DIPLOMACY_MAKE_PEACE_NOTIFICATION_SUMMARY_INITIAL", PlayerConfigurations[playerID]:GetLeaderName()));
	
	-- Set the tooltip
	if(pPlayerConfig ~= nil) then
		local leaderTypeName:string = pPlayerConfig:GetLeaderTypeName();
		if(leaderTypeName ~= nil) then
			-- Append GetExtendedTooltip string to the end of the tooltip created by LeaderIcon
			--if (not GameConfiguration.IsAnyMultiplayer() or not isHuman) then
				local civData:string = GetExtendedTooltip(playerID);
				local currentTooltipString = instance.Portrait:GetToolTipString();
				instance.Portrait:SetToolTipString(currentTooltipString..civData);
			--end
		end
	end
	
end

function OnStartOfLocalPlayerTurn()
	--print("EDR: Making isDiplomacyRibbonUpdated = false on start of player turn in " .. ContextPtr:LookUpControl(".."):GetID());
	isDiplomacyRibbonUpdated = false;
	UpdateLeaders();
end

--ARISTOS: to manage mouse over leader icons to show relations
function OnInputHandler( pInputStruct:table )
  local uiKey :number = pInputStruct:GetKey();
  local uiMsg :number = pInputStruct:GetMessageType();
  if uiMsg == KeyEvents.KeyDown then
    if uiKey == Keys.VK_CONTROL then
      if m_isCTRLDown == false then
        m_isCTRLDown = true;
      end
    end
  end
  if uiMsg == KeyEvents.KeyUp then
    if uiKey == Keys.VK_CONTROL then
      if m_isCTRLDown == true then
        m_isCTRLDown = false;
      end
    end
  end
  if uiMsg == MouseEvents.MButtonDown then
    if m_isCTRLDown == false then
      m_isCTRLDown = true;
    end
    if(EDR_hoveringOverPortrait) then
      return true;
    end
  end
  if uiMsg == MouseEvents.MButtonUp then
    if m_isCTRLDown == true then
      m_isCTRLDown = false;
    end
    if(EDR_hoveringOverPortrait) then
      return true;
    end
  end

end
ContextPtr:SetInputHandler( OnInputHandler, true );
--ARISTOS: End

function Init()
	Events.DiplomacySessionClosed.Add( UpdateLeaders );
	Events.LocalPlayerTurnBegin.Add( OnStartOfLocalPlayerTurn );
end
Init()
