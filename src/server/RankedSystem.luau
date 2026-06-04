-- Ranked rounds, survival accum scoring, and end-of-round rewards.

local RankedSystem = {}

local G: any = nil

function RankedSystem.addRankedPoints(player: Player, delta: number)
	if not G then
		return
	end
	if G.playerRankedPoints[player] == nil or delta == 0 then
		return
	end
	G.playerRankedPoints[player] = (G.playerRankedPoints[player] :: number) + delta
end

function RankedSystem.getRankedTimeRemainingSec(): number
	if not G then
		return 0
	end
	local elapsed = (tick() - G.rankedRoundStart) % G.RANKED_ROUND_SEC
	return math.max(0, math.floor(G.RANKED_ROUND_SEC - elapsed))
end

local function endRankedRound()
	local rows: { { p: Player, score: number } } = {}
	for _, plr in G.Players:GetPlayers() do
		if G.playerRankedPoints[plr] ~= nil then
			table.insert(rows, { p = plr, score = G.playerRankedPoints[plr] :: number })
		end
	end
	table.sort(rows, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.p.UserId < b.p.UserId
	end)

	local payload: { { place: number, name: string, score: number, reward: string } } = {}

	for i = 1, math.min(3, #rows) do
		local r = rows[i]
		local rewardLabel: string
		if i == 1 then
			G.playerRankedWins[r.p] = (G.playerRankedWins[r.p] or 0) + 1
			rewardLabel = "Epic chest + 50 coins"
			local sn, rr = G.rollPlaytimeEpicChest()
			G.grantSkinFromRoll(r.p, sn, rr)
			G.addCoins(r.p, 50)
		elseif i == 2 then
			rewardLabel = "Rare chest + 25 coins"
			local sn, rr = G.rollRandomSkinShopRare()
			G.grantSkinFromRoll(r.p, sn, rr)
			G.addCoins(r.p, 25)
		else
			rewardLabel = "Common chest + 10 coins"
			local sn, rr = G.rollRandomSkinWorld()
			G.grantSkinFromRoll(r.p, sn, rr)
			G.addCoins(r.p, 10)
		end
		table.insert(payload, {
			place = i,
			name = r.p.Name,
			score = r.score,
			reward = rewardLabel,
		})
	end

	for _, plr in G.Players:GetPlayers() do
		if G.playerRankedWinStreak[plr] == nil then
			continue
		end
		if #rows >= 1 and plr == rows[1].p then
			local w = (G.playerRankedWinStreak[plr] :: number) + 1
			G.playerRankedWinStreak[plr] = w
			if w >= 3 then
				G.voidBeastUnlocked:FireClient(plr)
				G.playerHasVoidApex[plr] = true
				G.applyStoredAnimalLook(plr)
				G.playerRankedWinStreak[plr] = 0
			end
		else
			G.playerRankedWinStreak[plr] = 0
		end
	end

	G.roundEnd:FireAllClients(payload)

	for _, plr in G.Players:GetPlayers() do
		if G.playerRankedPoints[plr] ~= nil then
			G.playerRankedPoints[plr] = 0
			G.playerRankedSurvivalAccum[plr] = 0
		end
	end
end

function RankedSystem.mount(game: any)
	G = game
	G.addRankedPoints = RankedSystem.addRankedPoints
	G.getRankedTimeRemainingSec = RankedSystem.getRankedTimeRemainingSec
	G.rankedRoundStart = tick()
	G.lastRankedRoundIndex = math.floor((tick() - G.rankedRoundStart) / G.RANKED_ROUND_SEC)

	task.spawn(function()
		G.rankedTimerSync:FireAllClients(RankedSystem.getRankedTimeRemainingSec())
		while true do
			task.wait(1)
			local idx = math.floor((tick() - G.rankedRoundStart) / G.RANKED_ROUND_SEC)
			while G.lastRankedRoundIndex < idx do
				endRankedRound()
				G.lastRankedRoundIndex = G.lastRankedRoundIndex + 1
			end
			G.rankedTimerSync:FireAllClients(RankedSystem.getRankedTimeRemainingSec())
		end
	end)
end

return RankedSystem
