# Snack Check

A World of Warcraft: Forever addon that gives you two buttons, one to eat and one to drink. Each one uses the best food or water in your bags, so you never have to dig through them after a pull. It warns you when you're running low, too.

## What it does

- **Picks the best item for you.** The highest-level food and drink your character can use, with leftovers from smaller stacks used up first. Buff food (anything that gives Well Fed) is never used automatically.
- **Eats the free stuff first.** Conjured food and water from a mage is used before anything you bought, even before a pinned item, so you don't burn through your own supply. Low-stock warnings ignore conjured items, since you can't buy more of them. Mages are the exception: once they know Conjure Food or Conjure Water, the warnings for that one track their conjured supply and tell them to conjure more.
- **Lets you pin your own choice.** Hover a button and a list of everything in your bags pops up. Click an item to always use that one; click it again to go back to automatic. If a pinned item runs out, the button falls back to the best one you have and picks your pin up again once you restock. Pins are saved per character.
- **Warns you before you run dry.** You get a message when the item a button is about to use drops below your threshold, and when you're out completely. One reminder at login if you're already low, then nothing until something actually changes.
- **Works on your action bars if you prefer.** Snack Check can create `SC Eat`, `SC Drink` and `SC Eat+Drink` macros that always point at the right item, with the icon, count and tooltip you'd expect.
- **Has its own key bindings.** Eat, drink, or both at once.

Characters without mana don't get a drink button.

## Installing

1. Download the latest release zip from the [Releases](../../releases) page.
2. Extract it into the `Interface\AddOns` folder of your WoW Forever install. During the beta that's `World of Warcraft\_classic_beta_\Interface\AddOns`.
3. Make sure the folder is called exactly `SnackCheck`. If you used **Code → Download ZIP** instead of a release, GitHub names it `SnackCheck-main`, and the game won't load it until you rename it.
4. Restart the game (a `/reload` isn't enough for a new addon).

## Using it

- Click a button to eat or drink.
- **Shift-drag** a button to move both of them.
- Hover a button to open the pick list.

## Settings

Open them with `/snack`, or through Options → AddOns → Snack Check.

**Warnings**

| Setting | What it does |
|---|---|
| Food / Drink | Warn when you drop below this many. `0` turns the low warning off; running out always warns. |
| Show in chat | Warnings as a chat line. |
| Show on screen | Warnings in the middle of the screen. |
| Remind at login | One reminder when you log in already low. The login reminder only goes to chat, unless chat warnings are off. |

**Buttons**

| Setting | What it does |
|---|---|
| Match action bar | Copy the size and spacing of your main action bar. On by default. |
| Button size / Spacing | Your own size and gap. Only editable with Match action bar unticked. |
| Stack vertically | Put Drink under Eat instead of beside it. The pick list then opens to the side. |
| Count size | Size of the number in the corner of the buttons. |
| Show buttons | Hide the floating buttons, for example if you only use the macros. |

The number boxes have arrows next to them. Click for 1, shift-click for 5, or hold to keep going.

**Key bindings**

Click a binding button, press the key you want, done. Right-click clears it. The same bindings show up under Options → Keybindings → AddOns.

**Action bar macros**

Tick **Make macros** to create the three macros, then use the **Eat / Drink / Both** buttons to put one on your cursor and drop it onto a bar. Unticking deletes the macros again. They're per character and use three of your character macro slots.

## Commands

| Command | |
|---|---|
| `/snack` or `/food` | Open the settings. |
| `/snack reset` | Move the buttons back to the middle of the screen. |

## Good to know

- Nothing changes in combat. The game doesn't allow addons to swap items or move secure buttons mid-fight, so Snack Check catches up as soon as combat ends.
- It works on non-English clients. Food and drink are recognised through the game's own spell names, not English text.
- Settings and bindings are shared across your characters; pins and macros are per character.

## License

GPL-3.0, see [LICENSE](LICENSE). Versions up to 0.2.1 were released under MIT.
