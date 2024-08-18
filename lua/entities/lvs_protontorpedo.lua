AddCSLuaFile()

ENT.Base = "lvs_missile"

ENT.Type            = "anim"

ENT.PrintName = "Proton Torpedo"
ENT.Author = "Luna"
ENT.Information = "geht ab wie'n z�pfchen"
ENT.Category = "[LVS]"

ENT.Spawnable		= true
ENT.AdminOnly		= true

ENT.ExplosionEffect = "lvs_proton_explosion"
ENT.GlowColor = Color( 0, 255, 100, 255 )

-- global variables
c=0
tEnd=20
iterations=100
a = 1

if SERVER then
	function ENT:GetDamage() 
		return (self._dmg or 400)
	end

	function ENT:GetRadius() 
		return (self._radius or 150)
	end

	function ENT:GetTarget()
		if IsValid( self:GetNWTarget() ) then
			local Pos = self:GetPos()
			local tPos = self:GetTargetPos()

			local Sub = tPos - Pos
			local Len = Sub:Length()
			local Dir = Sub:GetNormalized()
			local Forward = self:GetForward()

			local AngToTarget = math.deg( math.acos( math.Clamp( Forward:Dot( Dir ) ,-1,1) ) )

			local LooseAng = math.min( Len / 100, 90 )

			if AngToTarget > LooseAng then
				--self:SetNWTarget( NULL )
				print("reset because : ", AngToTarget, " > ", LooseAng)
			end
		end

		return self:GetNWTarget()
	end

	function ENT:GetTargetPos()
		local Target = self:GetNWTarget()

		if not IsValid( Target ) then return Vector(0,0,0) end

		-- if isfunction( Target.GetShield ) then
		-- 	if Target:GetShield() > 0 then
		-- 		return Target:LocalToWorld( VectorRand() * math.random( -1000, 1000 ) )
		-- 	end
		-- end

		-- if isfunction( Target.GetMissileOffset ) then
		-- 	return Target:LocalToWorld( Target:GetMissileOffset() )
		-- end

		return Target:GetPos()
	end

	function ENT:PhysicsSimulate( phys, deltatime )
		phys:Wake()

		local speedMissile = self:GetThrust()*self:GetSpeed()

		local xm = self:GetPos()
		local velL = self:WorldToLocal( xm + self:GetVelocity() )
		local vm = Vector( speedMissile,0,0)
		local ForceLinear = (vm - velL) * deltatime

		local Target = self:GetTarget()
		local p2 = self:GetTargetPos()

		if self.p0 == nil then
			self.p0 = p2
			print("set p0")

			if not IsValid( Target ) then
				return (-phys:GetAngleVelocity() * 250 * deltatime), ForceLinear, SIM_LOCAL_ACCELERATION
			end
		
			local AngForce = -self:WorldToLocalAngles( (self:GetTargetPos() - xm):Angle() )
		
			local ForceAngle = (Vector(AngForce.r,-AngForce.p,-AngForce.y) * self:GetTurnSpeed() - phys:GetAngleVelocity() * 5 ) * 250 * deltatime
		
			return ForceAngle, ForceLinear, SIM_LOCAL_ACCELERATION

		elseif self.p1 == nil then
			self.p1 = p2
			self.d1 = deltatime
			print("set p1")

			if not IsValid( Target ) then
				return (-phys:GetAngleVelocity() * 250 * deltatime), ForceLinear, SIM_LOCAL_ACCELERATION
			end
		
			local AngForce = -self:WorldToLocalAngles( (self:GetTargetPos() - xm):Angle() )
		
			local ForceAngle = (Vector(AngForce.r,-AngForce.p,-AngForce.y) * self:GetTurnSpeed() - phys:GetAngleVelocity() * 5 ) * 250 * deltatime
		
			return ForceAngle, ForceLinear, SIM_LOCAL_ACCELERATION
		
		else
			if Target~=NULL then
				self.m = Target:GetPhysicsObject():GetMass()/a
			else
				return (-phys:GetAngleVelocity() * 250 * deltatime), ForceLinear, SIM_LOCAL_ACCELERATION
			end

			local t2 = self.d1 + deltatime
			local alpha = self.p1 - self.p0
			local beta = p2 - self.p0
			local exp2 = math.exp(-t2 / self.m)
			local exp1 = math.exp(-self.d1 / self.m)

			-- Calculating gamma
			local gamma = (alpha * t2 - beta * self.d1) / (-deltatime - self.d1 * exp2 + t2 * exp1)
			if self.gammaMean == nil then
				self.gammaMean = gamma
			else
				self.gammaMean = (self.gammaMean+gamma)/2
			end
			gamma = self.gammaMean

			-- Calculating vf0
			local vf0 = (alpha + gamma * (1 - exp1)) / self.d1
			if self.vf0 == nil then
				self.vf0 = vf0
			else
				self.vf0 = (self.vf0+vf0)/2
			end
			vf0 = self.vf0

			-- Define the recon function
			local function recon(t)
				return self.p0 + vf0 * (t + t2) - gamma * (1 - math.exp(-(t + t2) / self.m))
			end
			
			-- Define the function for root finding
			local function f(t)
				return (recon(t) - xm - vm * c):Length() - vm:Length() * (t - c)
			end
			
			-- Find the intercept time
			local interceptTime = root(f, tEnd, iterations)
			
			-- Return the intercept point and time
			local interceptPoint = recon(interceptTime)
			
			print("deltatime: ", deltatime)
			-- Update Variables
			self.p0 = self.p1
			self.p1 = p2
			self.d1 = deltatime

			--print("intercept point: ", interceptPoint)
			local AngForce = -self:WorldToLocalAngles( (interceptPoint - xm):Angle() )
		
			local ForceAngle = (Vector(AngForce.r,-AngForce.p,-AngForce.y) * self:GetTurnSpeed() - phys:GetAngleVelocity() * 5 ) * 250 * deltatime
		
			return ForceAngle, ForceLinear, SIM_LOCAL_ACCELERATION
		end
	end

	function root(f, tEnd, iterations) --helper function
		local tStart = 0

		if f(tStart)<0 and f(tEnd)>0 then
			tStart = tEnd
			tEnd = 0
		end
		if f(tEnd) > 0 then
			return tEnd
		end
		
		for i = 0, iterations do
			local t = (tEnd + tStart) / 2
			if f(t) > 0 then
				tStart = t
			else
				tEnd = t
			end
		end
		
		return (tEnd + tStart) / 2
	end	

	return
end


ENT.GlowMat = Material( "sprites/light_glow02_add" )

function ENT:Enable()	
	if self.IsEnabled then return end

	self.IsEnabled = true

	self.snd = CreateSound(self, "npc/combine_gunship/gunship_crashing1.wav")
	self.snd:SetSoundLevel( 80 )
	self.snd:Play()

	local effectdata = EffectData()
		effectdata:SetOrigin( self:GetPos() )
		effectdata:SetEntity( self )
	util.Effect( "lvs_proton_trail", effectdata )
end

function ENT:Draw()
	if not self:GetActive() then return end

	self:DrawModel()

	render.SetMaterial( self.GlowMat )

	local pos = self:GetPos()
	local dir = self:GetForward()

	for i = 0, 30 do
		local Size = ((30 - i) / 30) ^ 2 * 128

		render.DrawSprite( pos - dir * i * 7, Size, Size, self.GlowColor )
	end
end