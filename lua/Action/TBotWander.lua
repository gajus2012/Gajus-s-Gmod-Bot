-- TBotWanderAction.lua
-- Purpose: A simple wandering action for TBot.
-- Notes: This is a conservative, well-commented template that chooses random nearby positions
--        and records them on the bot's table. It attempts to call a movement helper (me:MoveTo)
--        if available; it will not error if the helper doesn't exist. Use SuspendFor with
--        an existing path-following action (e.g. TBotFollowPath) if you have one and want
--        the bot to actually pathfind to the chosen point.

DEFINE_BASECLASS( "TBotWander" )

local TBotWanderActionMeta = {}

function TBotWanderActionMeta:__index( key )

	-- Search the metatable.
	local val = TBotWanderActionMeta[ key ]
	if val != nil then return val end	
	
	-- Search the base class.
	val = BaseClass[ key ]
	if val != nil then return val end	
	
	return nil	
	
end

function TBotWanderAction()
	local wander = TBotBaseAction()

	wander.m_wanderTimer = util.Timer()
	wander.m_nextWanderTime = 0
	wander.m_wanderRadius = 512 -- default wander radius in units
	wander.m_minInterval = 3    -- minimum seconds between choosing new wander points
	wander.m_maxInterval = 8    -- maximum seconds between choosing new wander points
	wander.m_currentTarget = nil

	setmetatable( wander, TBotWanderActionMeta )

	return wander

end

function TBotWanderActionMeta:GetName()

	return "WanderAction"	
	
end

function TBotWanderActionMeta:InitialContainedAction( me )

	-- No contained action by default. This could return a monitoring action if desired.
	return nil

end

function TBotWanderActionMeta:OnStart( me, priorAction )

	self.m_nextWanderTime = CurTime() + math.Rand( 0, 1 )
	self.m_currentTarget = nil
	self.m_wanderTimer:Start()

	return self:Continue()

end

-- Helper: pick a random reachable position around the bot. This is conservative and
-- does minimal checks; adapt it to your map/pathfinder if you have one.
function TBotWanderActionMeta:SelectWanderPosition( me )

	local origin = me:GetPos()
	local radius = tonumber( self.m_wanderRadius ) or 512

	-- Choose a random horizontal direction and distance
	local angle = math.Rand( 0, math.pi * 2 )
	local dist = math.Rand( math.min( 64, radius * 0.2 ), radius )
	local dx = math.cos( angle ) * dist
	local dy = math.sin( angle ) * dist
	local candidate = origin + Vector( dx, dy, 0 )

	-- Trace downwards from a point above the candidate to find ground
	local traceStart = candidate + Vector( 0, 0, 64 )
	local traceEnd = candidate - Vector( 0, 0, 256 )
	local tr = util.TraceLine( { start = traceStart, endpos = traceEnd, filter = me } )

	if tr.Hit and tr.HitPos then
		-- Return a point slightly above the ground so the bot doesn't get stuck in the floor
		return tr.HitPos + Vector( 0, 0, 8 )
	end

	-- Fallback: return the original candidate slightly raised
	return candidate + Vector( 0, 0, 8 )

end

function TBotWanderActionMeta:Update( me, interval )

	local botTable = me:GetTable()

	-- If the bot is dead or disabled, stop wandering
	if not me:Alive() then
		return self:TryChangeTo( TBotDead(), TBotEventResultPriorityType.RESULT_CRITICAL, "I died while wandering" )
	end

	-- If the bot is in combat, suspend wandering and let the main action handle it
	if me:IsInCombat() then
		return self:TryContinue()
	end

	-- Choose a new wander point when the timer elapses
	if CurTime() >= ( self.m_nextWanderTime or 0 ) then
		local pos = self:SelectWanderPosition( me )
		self.m_currentTarget = pos
		botTable.WanderTarget = pos -- Expose target on bot table for other systems to use

		-- If a path-following action exists you can suspend for it here. Example (commented):
		-- return self:SuspendFor( TBotFollowPath( pos ), "Wandering to random point" )

		-- Attempt to call a conservative movement helper if available. Use pcall to avoid errors
		local ok, _ = pcall( function()
			if isfunction( me.MoveTo ) then
				me:MoveTo( pos )
			end
		end )

		-- Set the next wander time
		self.m_nextWanderTime = CurTime() + math.Rand( self.m_minInterval, self.m_maxInterval )
	end

	-- Optional: make the bot look toward the current target to make movement appear natural
	if self.m_currentTarget then
		me:LookAt( self.m_currentTarget ) -- if LookAt exists this will help; pcall avoided intentionally
	end

	return self:Continue()

end

function TBotWanderActionMeta:OnEnd( me, nextAction )

	-- Clear wander target when leaving
	local botTable = me:GetTable()
	botTable.WanderTarget = nil
	self.m_currentTarget = nil

	return

end

function TBotWanderActionMeta:OnSuspend( me, interruptingAction )

	-- Preserve state; resume choosing points when resumed
	return self:Continue()

end

function TBotWanderActionMeta:OnResume( me, interruptingAction )

	-- Continue wandering
	return self:Continue()

end

-- Query hooks the base action system may call. Keep defaults here.
function TBotWanderActionMeta:ShouldPickUp( me, item )

	return TBotQueryResultType.ANSWER_UNDEFINED

end

function TBotWanderActionMeta:ShouldHurry( me )

	return TBotQueryResultType.ANSWER_UNDEFINED

end

function TBotWanderActionMeta:ShouldRetreat( me )

	return TBotQueryResultType.ANSWER_UNDEFINED

end

function TBotWanderActionMeta:ShouldAttack( me, them )

	return TBotQueryResultType.ANSWER_UNDEFINED

end

return TBotWanderAction
