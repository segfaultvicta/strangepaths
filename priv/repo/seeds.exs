# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Strangepaths.Repo.insert!(%Strangepaths.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Strangepaths.Repo

Strangepaths.Accounts.register_god(%{
  email: "jon.c.cantwell@gmail.com",
  nickname: "Teakwood",
  password: "B4h4mUtz3r0",
  password_confirmation: "B4h4mUtz3r0"
})

Strangepaths.Accounts.register_admin(%{
  email: "icecylee@nerds.net",
  nickname: "Icecylee",
  password: "123456",
  password_confirmation: "123456"
})

Strangepaths.Accounts.register_user(%{
  email: "testone@sanctuary.com",
  nickname: "Testone",
  password: "123456",
  password_confirmation: "123456"
})

Strangepaths.Accounts.register_user(%{
  email: "testtwo@sanctuary.com",
  nickname: "Testtwo",
  password: "123456",
  password_confirmation: "123456"
})

# name: name,
# principle: principle,
# type: type,
# aspect_id: aspect_id,
# rules: rules,
# [glory_rules: glory_rules]

## DRAGON

# the Fang
Strangepaths.Cards.create_card(%{
  name: "Warmonger",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 1,
  rules: "Each fight, Deal +2 damage with your first damaging Rite."
})

Strangepaths.Cards.create_card(%{
  name: "Will to Fight - Fang",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 1,
  rules: "+3 Dragon Tolerance."
})

Strangepaths.Cards.create_card(%{
  name: "Eating Victory",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 1,
  rules: "Whenever an enemy is defeated, you Recover 1."
})

Strangepaths.Cards.create_card(%{
  name: "That's When I Carried You",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 1,
  rules: "Whenever an ally is defeated, your next damaging Rite does +3 damage."
})

Strangepaths.Cards.create_card(%{
  name: "Gut Feeling",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 1,
  rules:
    "When you engage, you may draw up to 2. If you do, discard the same amount of cards afterwards."
})

Strangepaths.Cards.create_card(%{
  name: "I Am The Odds",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 1,
  rules:
    "When you engage and there are more enemies than allies, your Dragon Tolerance is +3 this battle, and you draw +1 card."
})

Strangepaths.Cards.create_card(%{
  name: "Bash",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 1,
  rules: "Strike 3.",
  glory_rules: "Strike 5."
})

Strangepaths.Cards.create_card(%{
  name: "Wind Up",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 1,
  rules: "Strike 1. Your next damaging Rite does +2 damage.",
  glory_rules: "Strike 1. Your next damaging Rite does +4 damage."
})

Strangepaths.Cards.create_card(%{
  name: "Crush",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 1,
  rules: "Strike 4.",
  glory_rules: "Strike 7."
})

Strangepaths.Cards.create_card(%{
  name: "Second Wind",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 1,
  rules: "You Recover 2 and draw 1.",
  glory_rules: "You Recover 2 and draw 2."
})

Strangepaths.Cards.create_card(%{
  name: "Guarded Strike",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 1,
  rules: "Strike 2. You defend 2.",
  glory_rules: "Strike 2. You defend 4."
})

Strangepaths.Cards.create_card(%{
  name: "Entrench",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 1,
  rules: "Discard any number of cards. For each: Defend 2.",
  glory_rules: "Discard any number of cards. For each: Defend 3."
})

Strangepaths.Cards.create_card(%{
  name: "Neutrality Ender",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 1,
  rules: "Strike 1. If the target's last Rite was colorless, +3 damage.",
  glory_rules: "Strike 1. If the target's last Rite was colorless, +5 damage."
})

Strangepaths.Cards.create_card(%{
  name: "Death Parade",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 1,
  rules: "Strike 3. If this defeats an enemy, this doesn't end your turn.",
  glory_rules: "Strike 5. If this defeats an enemy, this doesn't end your turn."
})

Strangepaths.Cards.create_card(%{
  name: "Break",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 1,
  rules: "Strike 2. Until end of round, they take +1 damage when struck.",
  glory_rules: "Strike 2. Until end of round, they take +2 damage when struck."
})

Strangepaths.Cards.create_card(%{
  name: "Wild Swing",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 1,
  rules: "Strike 2. Struck target draws 1. You may act again at the end of the round.",
  glory_rules: "Strike 3. Struck target draws 1. You may act again at the end of the round."
})

# the Claw
Strangepaths.Cards.create_card(%{
  name: "Combat Instinct",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 2,
  rules: "When you Engage in combat, draw +1 extra card into your opening hand."
})

Strangepaths.Cards.create_card(%{
  name: "Will to Fight - Claw",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 2,
  rules: "+3 Dragon Tolerance."
})

Strangepaths.Cards.create_card(%{
  name: "Honed Combat Instinct",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 2,
  rules: "When you Engage in combat, draw +2 extra cards into your opening hand, rather than 1."
})

Strangepaths.Cards.create_card(%{
  name: "Combat Reflexes",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 2,
  rules: "The first time you're damaged in each combat encounter, Draw 2."
})

Strangepaths.Cards.create_card(%{
  name: "Pragmatism",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 2,
  rules: "Each time an ally is defeated, Draw 1."
})

Strangepaths.Cards.create_card(%{
  name: "Momentum",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 2,
  rules: "Each time an enemy is defeated, Draw 1."
})

Strangepaths.Cards.create_card(%{
  name: "Swipe",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 2,
  rules: "Strike 2. Targets 1.",
  glory_rules: "Strike 2. Targets 2."
})

Strangepaths.Cards.create_card(%{
  name: "Quick Hit",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 2,
  rules: "Strike 2. This doesn't end your turn.",
  glory_rules: "Strike 3. This doesn't end your turn."
})

Strangepaths.Cards.create_card(%{
  name: "Shifting Strike",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 2,
  rules: "Strike 4. You Discard 1, then Draw 1.",
  glory_rules: "Strike 4. You Discard 1, then Draw 2."
})

Strangepaths.Cards.create_card(%{
  name: "Trip",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 2,
  rules: "Strike 3. The target Discards 1 of their choosing.",
  glory_rules: "Strike 4. The target Discards 1 of your choosing."
})

Strangepaths.Cards.create_card(%{
  name: "Tumbling Strike",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 2,
  rules: "Strike 2 against a target which has already acted this round. You Defend 2.",
  glory_rules: "Strike 3 against a target which has already acted this round. You Defend 3."
})

Strangepaths.Cards.create_card(%{
  name: "Adrenaline Surge",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 2,
  rules: "Strike 3. If your hand is empty, Draw 2.",
  glory_rules: "Strike 3. If your hand is empty, Draw 4."
})

Strangepaths.Cards.create_card(%{
  name: "Rushdown",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 2,
  rules: "Strike 3 against a target which hasn't acted this round. This doesn't end your turn.",
  glory_rules:
    "Strike 4 against a target which hasn't acted this round. This doesn't end your turn."
})

Strangepaths.Cards.create_card(%{
  name: "Feint",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 2,
  rules: "Draw 3. This doesn't end your turn.",
  glory_rules: "Draw 5. This doesn't end your turn."
})

Strangepaths.Cards.create_card(%{
  name: "Backstab",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 2,
  rules: "Strike 1. Against a target which has already acted this round, deal +3 damage.",
  glory_rules: "Strike 1. Against a target which has already acted this round, deal +5 damage."
})

Strangepaths.Cards.create_card(%{
  name: "Pierce Through",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 2,
  rules: "Strike 2. Against targets with Defense, deal +2 damage.",
  glory_rules: "Strike 2. Against targets with Defense, deal +4 damage."
})

# the Scale
Strangepaths.Cards.create_card(%{
  name: "The Unwavering",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 3,
  rules: "+3 Dragon Tolerance."
})

Strangepaths.Cards.create_card(%{
  name: "Will to Fight - Scale",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 3,
  rules: "+3 Dragon Tolerance."
})

Strangepaths.Cards.create_card(%{
  name: "Guarded Hand",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 3,
  rules: "Defend 2 anytime you Refresh."
})

Strangepaths.Cards.create_card(%{
  name: "Til the Last",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 3,
  rules: "Whenever an ally is defeated, you and all other allies Recover 1."
})

Strangepaths.Cards.create_card(%{
  name: "Reassessment",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 3,
  rules: "At the start of each of your turns, you may Discard 1. If you do, Draw 1."
})

Strangepaths.Cards.create_card(%{
  name: "Grin And Bare It",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 3,
  rules: "Anytime you draw a status card into your hand, Defend 2."
})

Strangepaths.Cards.create_card(%{
  name: "Block",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 3,
  rules: "Defend 3.",
  glory_rules: "Defend 3. This does not end your turn."
})

Strangepaths.Cards.create_card(%{
  name: "Wall",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 3,
  rules: "Defend 2. Target 1.",
  glory_rules: "Defend 2. Target All."
})

Strangepaths.Cards.create_card(%{
  name: "Cover",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 3,
  rules: "Defend 2. Target 2.",
  glory_rules: "Defend 3. Target 2."
})

Strangepaths.Cards.create_card(%{
  name: "Vigilance",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 3,
  rules: "Strike 2, then Defend 2 an ally.",
  glory_rules: "Strike 2, then Defend 4 an ally."
})

Strangepaths.Cards.create_card(%{
  name: "Taunt",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 3,
  rules: "Strike 2, and the enemy must target you if they perform an attack on their next turn.",
  glory_rules:
    "Strike 5, and the enemy must target you if they perform an attack on their next turn."
})

Strangepaths.Cards.create_card(%{
  name: "Protect",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 3,
  rules:
    "You Defend 2. For the remainder of the round, you may opt to become the target of any enemy attacks regardless of their chosen target.",
  glory_rules:
    "You Defend 4. For the remainder of the round, you may opt to become the target of any enemy attacks regardless of their chosen target."
})

Strangepaths.Cards.create_card(%{
  name: "Maintenance",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 3,
  rules: "Remove 1 status cards from a single target's deck.",
  glory_rules: "Remove All status cards from a single target's deck."
})

Strangepaths.Cards.create_card(%{
  name: "Rally Blow",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 3,
  rules: "Strike 2, then You Recover 2.",
  glory_rules: "Strike 4, then You Recover 2."
})

Strangepaths.Cards.create_card(%{
  name: "Reactive Shielding",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 3,
  rules: "Defend 3. Targets any ally which has been attacked since your last turn.",
  glory_rules: "Defend 4. Targets any ally which has been attacked since your last turn."
})

Strangepaths.Cards.create_card(%{
  name: "Shed Scales",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 3,
  rules:
    "Remove all of your Defense. Your next attack deals bonus damage equal to the amount of lost Defense.",
  glory_rules:
    "Remove all of your Defense. Your next attack deals bonus damage equal to the amount of lost Defense. This doesn't end your turn."
})

# the Breath
Strangepaths.Cards.create_card(%{
  name: "Snipe",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 4,
  rules:
    "If you choose not to engage in combat, you may still Draw 1 without accumulating any stress, and play this card by taking a single turn."
})

Strangepaths.Cards.create_card(%{
  name: "Will to Fight - Breath",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 4,
  rules: "+3 Dragon Tolerance."
})

Strangepaths.Cards.create_card(%{
  name: "No Pressure",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 4,
  rules:
    "Anytime you Engage in combat and your allies don't outnumber your foes, gain +1 Defense per enemy."
})

Strangepaths.Cards.create_card(%{
  name: "Opportunity Cost",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 4,
  rules:
    "At the start of each turn, you may Discard 1. If you do, select an ally; they immediately Draw 1."
})

Strangepaths.Cards.create_card(%{
  name: "Recoup",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 4,
  rules:
    "Whenever any combatant is defeated, place a random Rite from your discard pile into your hand."
})

Strangepaths.Cards.create_card(%{
  name: "Rearguard",
  principle: :Dragon,
  type: :Grace,
  aspect_id: 4,
  rules: "Whenever an ally Refreshes, gain +1 defense."
})

Strangepaths.Cards.create_card(%{
  name: "Shoot",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 4,
  rules: "Strike 2.",
  glory_rules: "Strike 2. Select a random Rite from your discard pile and place it in your hand."
})

Strangepaths.Cards.create_card(%{
  name: "Snap Shot",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 4,
  rules: "Strike 1. Deals +3 damage if the target hasn't acted yet this round.",
  glory_rules: "Strike 1. Deals +5 damage if the target hasn't acted yet this round."
})

Strangepaths.Cards.create_card(%{
  name: "Counter",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 4,
  rules:
    "You Defend 3. Until the end of the round, anytime you are attacks, immediately Strike 2 the target in response without taking a turn.",
  glory_rules:
    "You Defend 3. Until the end of the round, anytime you are attacks, immediately Strike 3 the target in response without taking a turn."
})

Strangepaths.Cards.create_card(%{
  name: "Tracer",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 4,
  rules: "Select a target. Next round, your first attack deals +3 damage against them.",
  glory_rules:
    "Select a target. Next round, your first attack deals +3 damage against them. This doesn't end your turn."
})

Strangepaths.Cards.create_card(%{
  name: "Deep Breath",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 4,
  rules: "Discard a Rite from your hand. Your next attack hits all enemy combatants.",
  glory_rules: "Your next attack hits all enemy combatants."
})

Strangepaths.Cards.create_card(%{
  name: "Blast",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 4,
  rules: "Strike 2. Targets 2.",
  glory_rules: "Strike 2. Targets 3."
})

Strangepaths.Cards.create_card(%{
  name: "War Cry",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 4,
  rules: "Until the end of this round, your allies deal +1 damage.",
  glory_rules: "Until the end of this round, your allies deal +2 damage."
})

Strangepaths.Cards.create_card(%{
  name: "Command",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 4,
  rules: "Select an ally. They may play an additional Rite on their turn.",
  glory_rules:
    "Select an ally. They may play an additional Rite on their turn. This doesn't end your turn."
})

Strangepaths.Cards.create_card(%{
  name: "Mana Burst",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 4,
  rules:
    "Strike 1. Deals +1 damage for each individual colored Rite used since your last turn. ie, if green and blue rites have been played since your last turn, but no red, black or white, this attack would deal 3 damage.",
  glory_rules:
    "Strike 1. Deals +2 damage for each individual colored Rite used since your last turn. ie, if green and blue rites have been played since your last turn, but no red, black or white, this attack would deal 5 damage."
})

Strangepaths.Cards.create_card(%{
  name: "Hip Shot",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 4,
  rules:
    "Strike 2, against a target which hasn't acted this round yet. This doesn't end your turn.",
  glory_rules:
    "Strike 3, against a target which hasn't acted this round yet. This doesn't end your turn."
})

# Red
Strangepaths.Cards.create_card(%{
  name: "Bonebreaker",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 9,
  rules:
    "Strike 5. Raise the Stakes: Someone on the losing side of this battle will suffer an injury.",
  glory_rules:
    "Strike 5. Piercing. Raise the Stakes: Someone on the losing side of this battle will suffer an injury."
})

Strangepaths.Cards.create_card(%{
  name: "Who Dares?",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 9,
  rules: "When the next enemy begins their turn, Strike 5 them.",
  glory_rules:
    "When the next enemy begins their turn, Strike 5 them. They can't Refresh that turn."
})

Strangepaths.Cards.create_card(%{
  name: "Wild and Pure and Forever Free",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 9,
  rules: "Play any number of cards that Strike. Then Discard your hand.",
  glory_rules: "Draw 2, then, play any number of cards that Strike. Then Discard your hand."
})

Strangepaths.Cards.create_card(%{
  name: "Invoke: Papyrus",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 9,
  rules:
    "Craft a Fiend with Tolerance 4. Whenever a Rite damages you, add a copy of that Rite to the Fiend's hand.",
  glory_rules:
    "Craft a Fiend with Tolerance 8. Whenever a Rite damages you, add a copy of that Rite to the Fiend's hand."
})

Strangepaths.Cards.create_card(%{
  name: "Everyone Dies Some Day",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 9,
  rules: "Place an Exposure in your hand and one other target's hand.",
  glory_rules: "Strike 2, then place an Exposure in your hand and one other target's hand."
})

Strangepaths.Cards.create_card(%{
  name: "Rage",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 9,
  rules: "Enchant yourself: Your damaging Rites deal +2 damage.",
  glory_rules:
    "Enchant yourself: Your damaging Rites deal +2 damage. Discard until you have only one card remaining, but this doesn't end your turn."
})

Strangepaths.Cards.create_card(%{
  name: "Heavy Strikes",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 9,
  rules:
    "Enchant yourself: Your Strikes also cause the target to place a Wound in their draw pile. Then, Strike 3.",
  glory_rules:
    "Enchant yourself: Your Strikes also cause the target to place a Wound in their draw pile. Then, Strike 5."
})

Strangepaths.Cards.create_card(%{
  name: "Beatdown",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 9,
  rules:
    "Strike 6. The target may Discard any number of Rites when hit by this attack; doing so allows them to reduce the damage taken by 2 per rite.",
  glory_rules:
    "Strike 9. The target may Discard any number of Rites when hit by this attack; doing so allows them to reduce the damage taken by 2 per rite."
})

Strangepaths.Cards.create_card(%{
  name: "Inferno",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 9,
  rules: "Strike 2. Targets All.",
  glory_rules: "Strike 3. Targets All."
})

Strangepaths.Cards.create_card(%{
  name: "Massive Pyre",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 9,
  rules:
    "Strike 5. Raise the Stakes: Something belonging to the losing party is burned beyond repair.",
  glory_rules:
    "Strike 5. Raise the Stakes: Something belonging to the losing party is burned beyond repair. (And it was important.)"
})

Strangepaths.Cards.create_card(%{
  name: "Might Makes Right",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 9,
  rules:
    "Strike 4. Raise the Stakes; The loser must submit to any one demand made by the winner, within reason.",
  glory_rules:
    "Strike 6. Raise the Stakes; The loser must submit to any one demand made by the winner, within reason."
})

Strangepaths.Cards.create_card(%{
  name: "Sucker Punch",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 9,
  rules:
    "Flip a coin. Heads, Strike 3 a target of your choice. Tales, increase your Stress by 1. This doesn't end your turn.",
  glory_rules:
    "Flip a coin. (Flip a second coin). Heads, Strike 3 a target of your choice. Tales, increase your Stress by 1. This doesn't end your turn."
})

Strangepaths.Cards.create_card(%{
  name: "Big Damn Hero",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 9,
  rules:
    "You Defend 4. One at any point in this battle, you may become the only target of a single damaging attack regardless of the attacker's intentions or the number of targets it would typically hit.",
  glory_rules:
    "You Defend 6. One at any point in this battle, you may become the only target of a single damaging attack regardless of the attacker's intentions or the number of targets it would typically hit."
})

Strangepaths.Cards.create_card(%{
  name: "Unnamed Stake Raiser",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 9,
  rules: "dicks dicks dicks",
  glory_rules: "butts butts butts"
})

Strangepaths.Cards.create_card(%{
  name: "Unnamed Stake Raiser #2",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 9,
  rules: "icecylee is cool",
  glory_rules: "peter is also cool"
})

# Blue
Strangepaths.Cards.create_card(%{
  name: "Reconjure",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 10,
  rules:
    "Targets each select a Rite from their discard pile and places it in their hand. Target 2.",
  glory_rules:
    "Targets each select a Rite from their discard pile and places it in their hand. Target 3."
})

Strangepaths.Cards.create_card(%{
  name: "Omen Forgery",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 10,
  rules:
    "Target chooses a Rite they know. Add 2 copies of that Rite to their hand. Those copies don't go into the Discard pile when played - instead, destroy them.",
  glory_rules:
    "Target chooses a Rite they know. Add 3 copies of that Rite to their hand. Those copies don't go into the Discard pile when played - instead, destroy them."
})

Strangepaths.Cards.create_card(%{
  name: "Insult Demands Answer",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 10,
  rules: "Strike 2 - If the struck target hasn't acted yet this round, they act next.",
  glory_rules: "Strike 4 - If the struck target hasn't acted yet this round, they act next."
})

Strangepaths.Cards.create_card(%{
  name: "Fateshunt",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 10,
  rules: "Move an Enchantment onto another target.",
  glory_rules:
    "Move an Enchantment onto another target. You may Copy that enchantment onto a third target."
})

Strangepaths.Cards.create_card(%{
  name: "Invoke: Lithos",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 10,
  rules:
    "Craft a Fiend with Tolerance 4. Whenever you discard a card, you may add a copy of that card to the Fiend's hand.",
  glory_rules:
    "Craft a Fiend with Tolerance 8. Whenever you discard a card, you may add a copy of that card to the Fiend's hand."
})

Strangepaths.Cards.create_card(%{
  name: "Confusion",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 10,
  rules: "Enchant Target: At the start of every round, the target must Refresh.",
  glory_rules:
    "Enchant Target: At the start of every round, the target must Refresh. This doesn't end your turn."
})

Strangepaths.Cards.create_card(%{
  name: "Stun",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 10,
  rules: "The targets Discard 1 of your choice. Targets All.",
  glory_rules: "The targets Discard 2 of your choice. Targets All."
})

Strangepaths.Cards.create_card(%{
  name: "Counterspell",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 10,
  rules:
    "Select a single Mana Color when used. The next time any combatant, friend or foe, use a Rite of the corresponding color, its effects are nullified.",
  glory_rules:
    "Select a single Mana Color when used. The next time any combatant, friend or foe, use a Rite of the corresponding color, its effects are nullified. Strike 3 the nullified target as well."
})

Strangepaths.Cards.create_card(%{
  name: "Defuse",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 10,
  rules:
    "Remove all Rites in your hand, and place them in any combination of your allies hands. Then, Draw 2.",
  glory_rules:
    "Remove all Rites in your hand, and place them in any combination of your allies hands. Then, Draw 4."
})

Strangepaths.Cards.create_card(%{
  name: "Suppress",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 10,
  rules: "Add 5 Wounds to the target's draw pile.",
  glory_rules: "Add 5 Wounds to the target's draw pile. This doesn't end your turn."
})

Strangepaths.Cards.create_card(%{
  name: "Invisible Chains",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 10,
  rules: "Strike 2, and place a Curse in a target's draw pile.",
  glory_rules: "Strike 4, and place a Curse in a target's draw pile."
})

Strangepaths.Cards.create_card(%{
  name: "Mirage",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 10,
  rules:
    "Strike 2, and you can redirect who the target's next Rite effects within limitations - attacks still hit foes, beneficial effects still effect allies.",
  glory_rules:
    "Strike 4, and you can redirect who the target's next Rite effects within limitations - attacks still hit foes, beneficial effects still effect allies."
})

Strangepaths.Cards.create_card(%{
  name: "Illusionary Wall",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 10,
  rules:
    "Discard any number of Rites in your hand, and Defend 3. Targets a number of allies equal to the number of Rites discarded.",
  glory_rules:
    "Discard any number of Rites in your hand, and Defend 5. Targets a number of allies equal to the number of Rites discarded."
})

Strangepaths.Cards.create_card(%{
  name: "Flux",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 10,
  rules: "Enchant Target: At the start of every round, Draw 1 and Discard 1.",
  glory_rules: "Enchant Target: At the start of every round, Draw 2 and Discard 2."
})

Strangepaths.Cards.create_card(%{
  name: "Mirror Image",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 10,
  rules:
    "Remove a single Rite from a target's hand, and place it in yours. The borrowed Rite returns from whence it came upon completion of the combat encounter.",
  glory_rules:
    "Remove a single Rite from a target's hand, and place it in yours. This doesn't end your turn. The borrowed Rite returns from whence it came upon completion of the combat encounter."
})

# Green
Strangepaths.Cards.create_card(%{
  name: "Rootblade",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 11,
  rules: "Strike 2. Rites in your hand right now will do +2 damage when next played.",
  glory_rules: "Strike 2. Rites in your hand right now will do +3 damage when next played."
})

Strangepaths.Cards.create_card(%{
  name: "Crush Claw",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 11,
  rules: "Strike 1. Then, remove all defense from the target.",
  glory_rules: "Strike 1. Then, remove all defense from the target. ???? no glory????"
})

Strangepaths.Cards.create_card(%{
  name: "Invoke: Lutum",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 11,
  rules:
    "Craft a Fiend with Tolerance 5. Whenever you use a Green Rite, add a copy of that Rite to its hand.",
  glory_rules:
    "Craft a Fiend with Tolerance 8. Whenever you use a Green Rite, add a copy of that Rite to its hand."
})

Strangepaths.Cards.create_card(%{
  name: "Viper Bite",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 11,
  rules: "Strike 1. Place a Poison card in the target's draw pile.",
  glory_rules: "Strike 3. Place a Poison card in the target's draw pile."
})

Strangepaths.Cards.create_card(%{
  name: "Erode",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 11,
  rules: "Strike 1. Place a Exposure card in the target's draw pile.",
  glory_rules: "Strike 3. Place a Exposure card in the target's draw pile."
})

Strangepaths.Cards.create_card(%{
  name: "The Natural Course",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 11,
  rules: "Strike 1. Deals +1 damage for every Divinity stack on you, then removes them.",
  glory_rules:
    "Strike 1. Deals +1 damage for every Divinity stack on you, then removes them. You Defend 1 for each Divinity stack on you, as well."
})

Strangepaths.Cards.create_card(%{
  name: "Brilliance",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 11,
  rules: "Gain +1 Divinity stack. Draw 1. This does not end your turn.",
  glory_rules: "Gain +2 Divinity stack. Draw 2. This does not end your turn."
})

Strangepaths.Cards.create_card(%{
  name: "Seed of Power",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 11,
  rules: "Strike 2. You gain +1 Divinity stack.",
  glory_rules: "Strike 2. You gain +3 Divinity stack."
})

Strangepaths.Cards.create_card(%{
  name: "Weather the Storm",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 11,
  rules: "Defend 2 a target. You gain +1 Divinity stack.",
  glory_rules: "Defend 2 a target. You gain +3 Divinity stacks."
})

Strangepaths.Cards.create_card(%{
  name: "Contemplate",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 11,
  rules: "You gain +3 Divinity stacks. Place a card from your Discard pile into your hand.",
  glory_rules: "You gain +5 Divinity stacks. Place a card from your Discard pile into your hand."
})

Strangepaths.Cards.create_card(%{
  name: "Death by a Thousand Cuts",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 11,
  rules: "Place 4 Flurry Rites into your draw pile.",
  glory_rules: "Place 6 Flurry Rites into your draw pile."
})

Strangepaths.Cards.create_card(%{
  name: "Flurry",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 11,
  rules: "Strike 1. This doesn't end your turn. Destroy this Rite."
})

Strangepaths.Cards.create_card(%{
  name: "Shared Growth",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 11,
  rules: "Draw 2. Target All.",
  glory_rules: "Draw 3. Target All."
})

Strangepaths.Cards.create_card(%{
  name: "Autumn Harvest",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 11,
  rules:
    "Select a target. They Draw 4, then Discard 4. Status card cannot be discarded during this process. You Recover 1 for each Status the target draws.",
  glory_rules:
    "Select a target. They Draw 4, then Discard 6. Status card cannot be discarded during this process. You Recover 1 for each Status the target draws."
})

Strangepaths.Cards.create_card(%{
  name: "Lurk",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 11,
  rules: "Draw 2. On your next turn, you may play an additional Rite.",
  glory_rules: "Draw 4. On your next turn, you may play an additional Rite."
})

Strangepaths.Cards.create_card(%{
  name: "The Final Seal is Broken",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 11,
  rules:
    "Strike 5. This Rite is always placed on the bottom of your draw pile any time it is shuffled.",
  glory_rules:
    "Strike 8. This Rite is always placed on the bottom of your draw pile any time it is shuffled."
})

# White
Strangepaths.Cards.create_card(%{
  name: "Stand Together",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 12,
  rules: "Defend 2, Target All.",
  glory_rules: "Defend 3, Target All."
})

Strangepaths.Cards.create_card(%{
  name: "Banishment",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 12,
  rules:
    "Target chooses: You Strike 5, or Raise the Stakes: The losers must immediately leave the area with no further incident.",
  glory_rules:
    "Target chooses: You Strike 5, or Raise the Stakes: The losers must immediately leave the area with no further incident.  Draw 1.)"
})

Strangepaths.Cards.create_card(%{
  name: "Superannihilate",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 12,
  rules: "Destroy a Fiend, Destroy an Enchantment, or Strike 3.",
  glory_rules: "Choose two: Destroy a Fiend, Destroy an Enchantment, or Strike 3."
})

Strangepaths.Cards.create_card(%{
  name: "Ivory Blood",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 12,
  rules: "Enchant Target: Whenever they use a Rite, they also Defend 2.",
  glory_rules: "Enchant Target: Whenever they use a Rite, they also Defend 3."
})

Strangepaths.Cards.create_card(%{
  name: "Invoke: Orichalca",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 12,
  rules:
    "Craft a Fiend with Tolerance 8. Each turn, it has this rite: \"Gold Law - Strike 0. From now on, Gold Laws do +1 damage.\"",
  glory_rules:
    "Craft a Fiend with Tolerance 12. Each turn, it has this rite: \"Gold Law - Strike 0. From now on, Gold Laws do +1 damage.\""
})

Strangepaths.Cards.create_card(%{
  name: "Restore",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 12,
  rules: "Recover 3.",
  glory_rules: "Recover 5."
})

Strangepaths.Cards.create_card(%{
  name: "Elixir",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 12,
  rules:
    "Select a single type of status card, and remove all instances of it from the target's deck. Target 1.",
  glory_rules:
    "Select a single type of status card, and remove all instances of it from the target's deck. Target All."
})

Strangepaths.Cards.create_card(%{
  name: "Fortress",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 12,
  rules: "Defend 4.",
  glory_rules: "Defend 7."
})

Strangepaths.Cards.create_card(%{
  name: "Martyr",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 12,
  rules:
    "Remove all status cards from your ally's decks. Place them into your draw pile. Distribute 1 Wound for each status you take on into any enemies deck in any way you like.",
  glory_rules:
    "Remove all status cards from your ally's decks. Place them into your draw pile. Distribute 2 Wounds for each status you take on into any enemies deck in any way you like."
})

Strangepaths.Cards.create_card(%{
  name: "Condemnation",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 12,
  rules:
    "Strike 2, and place an Expose into the targets draw pile. The target then Draws 2, and both must attack you with its next action if it has any attacks in hand, and must target you.",
  glory_rules:
    "Strike 2, and place an Expose into the targets draw pile. The target then Draws 5, and both must attack you with its next action if it has any attacks in hand, and must target you."
})

Strangepaths.Cards.create_card(%{
  name: "Serenity",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 12,
  rules: "Search your draw pile. Add any 1 Rite to your hand.",
  glory_rules: "Search your draw pile. Add any 2 Rites to your hand."
})

Strangepaths.Cards.create_card(%{
  name: "Ward",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 12,
  rules:
    "Enchant a target: Whenever the target is struck by an attack, they may shift it to you instead.",
  glory_rules:
    "Enchant a target: Whenever the target is struck by an attack, they may shift it to you instead. This doesn't end your turn."
})

Strangepaths.Cards.create_card(%{
  name: "Dying Light",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 12,
  rules:
    "Strike 1. Deals +2 damage for each combatant that have been defeated in this fight, friend or foe.",
  glory_rules:
    "Strike 2. Deals +3 damage for each combatant that have been defeated in this fight, friend or foe."
})

Strangepaths.Cards.create_card(%{
  name: "Instant Barrier",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 12,
  rules: "Defend 2. This doesn't end your turn.",
  glory_rules: "Defend 3. This doesn't end your turn."
})

Strangepaths.Cards.create_card(%{
  name: "Shining Nova",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 12,
  rules:
    "Enchant a target: If they act as lat as possible in the round, they may take perform an extra rite.",
  glory_rules:
    "Enchant a target: If they act as lat as possible in the round, they may take perform an extra rite. They Draw 1 at the start of their turn, as well.)"
})

# Black
Strangepaths.Cards.create_card(%{
  name: "Strangling Darkness",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 13,
  rules: "Strike 1. The next time the target Refreshes, they take 6 damage.",
  glory_rules: "Strike 3. The next time the target Refreshes, they take 6 damage."
})

Strangepaths.Cards.create_card(%{
  name: "Invoke: Vitriol",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 13,
  rules:
    "Craft a Fiend with Tolerance 2. While this Fiend exists, whenever you Strike a target they must choose and discard a card. Add a copy of that card to this Fiend's hand.",
  glory_rules:
    "Craft a Fiend with Tolerance 4. While this Fiend exists, whenever you Strike a target they must choose and discard a card. Add a copy of that card to this Fiend's hand."
})

Strangepaths.Cards.create_card(%{
  name: "Sorrowful Memory",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 13,
  rules:
    "Strike 1. Enchant the target: Whenever they Refresh, they must pay 2 Stress for each card they wish to draw, up to 7, instead of the normal amount.",
  glory_rules:
    "Strike 1. Enchant the target: Whenever they Refresh, they must pay 1 Stress for each card they wish to draw, up to 7, instead of the normal amount."
})

Strangepaths.Cards.create_card(%{
  name: "Devils Banquet",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 13,
  rules:
    "Place a Poison in your and one other target's deck. Then, Enchant yourself: Whenever any combatant draws a status card, you deal +1 damage with your next attack.",
  glory_rules:
    "Place a Poison in your and two other target's deck. Then, Enchant yourself: Whenever any combatant draws a status card, you deal +1 damage with your next attack."
})

Strangepaths.Cards.create_card(%{
  name: "Ennui",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 13,
  rules: "Discard your hand, then destroy a Rite in another target's hand. Target 1",
  glory_rules: "Discard your hand, then destroy a Rite in another target's hand. Target All"
})

Strangepaths.Cards.create_card(%{
  name: "Void Flare",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 13,
  rules: "You Discard 1, then perform two Strike 3 actions.",
  glory_rules: "You Discard 1, then perform two Strike 4 actions."
})

Strangepaths.Cards.create_card(%{
  name: "Living Shadow",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 13,
  rules: "Enchant Yourself: Whenever an ally draws a rite, you Draw 1.",
  glory_rules:
    "Enchant Yourself: Whenever an ally draws a rite, you Draw 1. (This doesn't end your turn.)"
})

Strangepaths.Cards.create_card(%{
  name: "Lethargy",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 13,
  rules: "Strike 3. The target must act last in the round if it has not yet acted.",
  glory_rules: "Strike 5. The target must act last in the round if it has not yet acted."
})

Strangepaths.Cards.create_card(%{
  name: "Midnight Veil",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 13,
  rules:
    "Force your allies to Discard any number of Rites. A single target then Defends 1 for each Rite discarded.",
  glory_rules:
    "Force your allies to Discard any number of Rites. A single target then Defends 2 for each Rite discarded."
})

Strangepaths.Cards.create_card(%{
  name: "Dark Prophecy",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 13,
  rules:
    "Select 2 Rites in your hand. They no longer end your turn the next time they're played.",
  glory_rules:
    "Select 3 Rites in your hand. They no longer end your turn the next time they're played."
})

Strangepaths.Cards.create_card(%{
  name: "Hex",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 13,
  rules: "Discard 1, then place a Curse in another target's hand.",
  glory_rules: "Discard 1, then place a Curse in another target's hand. GLORY????"
})

Strangepaths.Cards.create_card(%{
  name: "Forbidden Pact",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 13,
  rules:
    "You take on 3 Stress, and all attacks for the remainder of this round deal +2 damage. Raise the Stakes: If you lose the battle, a dark power comes calling for debts owed. This doesn't end your turn.",
  glory_rules:
    "You take on 1 Stress, and all attacks for the remainder of this round deal +2 damage. Raise the Stakes: If you lose the battle, a dark power comes calling for debts owed. This doesn't end your turn."
})

Strangepaths.Cards.create_card(%{
  name: "Heavy is the Crown",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 13,
  rules: "Strike 5 All your allies Discard 1.",
  glory_rules: "Strike 7. All your allies Discard 1."
})

Strangepaths.Cards.create_card(%{
  name: "Defiance",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 13,
  rules: "Strike 2. Deals +1 damage for each Enchantment on the target, or status in their hand.",
  glory_rules:
    "Strike 2. Deals +2 damage for each Enchantment on the target, or status in their hand."
})

Strangepaths.Cards.create_card(%{
  name: "Siphon Energy",
  principle: :Dragon,
  type: :Rite,
  aspect_id: 13,
  rules: "Strike 2. You Recover 1 for each Rite in the target's hand.",
  glory_rules: "Strike 4. You Recover 1 for each Rite in the target's hand."
})

# Status
Strangepaths.Cards.create_card(%{
  name: "Curse",
  principle: :Dragon,
  type: :Status,
  aspect_id: 14,
  rules: "While in your hand, your Rites are only half as effective."
})

Strangepaths.Cards.create_card(%{
  name: "Poison",
  principle: :Dragon,
  type: :Status,
  aspect_id: 14,
  rules:
    "When drawn, increase Stress by 2 and Draw 1. Then return this card to the draw pile. If multiple poison cards are drawn at once, resolve them all at once rather than individual so that you can't get stuck in an infinite poison loop."
})

Strangepaths.Cards.create_card(%{
  name: "Exposure",
  principle: :Dragon,
  type: :Status,
  aspect_id: 14,
  rules: "While in your hand, you take double damage from enemy attacks."
})

Strangepaths.Cards.create_card(%{
  name: "Wound",
  principle: :Dragon,
  type: :Status,
  aspect_id: 14,
  rules: "Does nothing, but clogs your deck to limit your options."
})
