# ProfitCraft

A World of Warcraft 1.12.1 (Vanilla) addon designed for the **Turtle WoW** private server. 
It calculates and displays the most profitable items to craft based on your current professions, taking into account market prices from the **Aux** addon.

## Features (Planned)
- View a unified **Profit Dashboard** instead of the restrictive default tradeskill window.
- See both **Learned** and **Unlearned** recipes you have the skill to craft.
- Instantly see the **Profit Margin** of any recipe, factoring in Reagent costs vs Crafted Item Value.
- Filter by learned vs unlearned, and see exactly where to acquire new recipes (e.g. Quests, Vendors, Drops).
- Manage a **Shopping List** to track how many reagents you need (and currently have) to craft multiple items.

## Dependencies
- **Aux Addon**: Must be installed, as ProfitCraft relies entirely on Aux's database to determine historical and current market values for both reagents and crafted goods.

## Installation for Turtle WoW
1. Download the latest release from this repository.
2. Extract the folder into your `World of Warcraft/Interface/AddOns/` directory.
3. Make sure the folder is named exactly `ProfitCraft` (remove any `-master` suffixes).
4. Restart your game client if it is already running.

## Contributing
This addon is fully open-sourced. Any Pull Requests to improve the internal Recipe Database, UI, or calculation logic are welcome!
