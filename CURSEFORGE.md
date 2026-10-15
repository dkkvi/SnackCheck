# Snack Check

If you're familiar with TrinketMenu, it's very similar, two buttons: one eats, one drinks. They always grab the best food and water in your bags, so you're not digging through them after every pull. It also tells you when you're running low, before you end up sitting there with nothing left. Bandages too, if you want them.

Made for WoW Forever since it's the version I play, feel free to fork my repo and change it to your version if you'd like.

## What it does

It picks the highest level food and drink your character can actually use. Leftovers from an older stack go first, so your bags don't fill up with stacks of 2. Buff food and drinks never get used unless you tell it to.

Got mage food or water? That goes first between buffs. Free food is free food. If you're the mage yourself, the warnings keep an eye on your conjured stuff instead and tell you when it's time to conjure more.

Hover over a button and you get a list of everything in your bags. Click one to always use that, click it again to let the addon pick. Buff food and drinks only get used when their buff is missing. When your pinned food runs out it just uses the next best thing, and switches back once you've restocked. Pins are per character.

You get a warning when the food or drink you're about to use drops below a number you set, and one when you're out. If you log in already low you get a single reminder. After that it only speaks up when something actually changes.

If you'd rather have it on your action bars, it can make macros that always point at the right item. There are key bindings too, for eating, drinking, or both at once.

No mana = no drink button. Sorry hydrohomies :(

Bandages are off by default. Tick **Enable bandages** in the settings and you get a third button. It grabs the best bandage your First Aid skill lets you use, and the list, pinning and warnings work just like food and drink. It gets its own key binding and macro too. Eat & drink still only does food and water.

## Installing

1.  Either use the CurseForge client or download it from here, or use my repo.
2.  If you're not using the CurseForge client, unzip it into `Interface\AddOns` in your WoW Forever folder. During the beta that's `World of Warcraft\_classic_beta_\Interface\AddOns`.

## Using it

Click to eat, drink or use a bandage. Shift-drag to move the buttons around. Hover to open the list.

## Settings

`/snack` opens the settings. They're also under Options → AddOns → Snack Check.

| Warnings                      |                                                                                                    |
| ----------------------------- |--------------------------------------------------------------------------------------------------- |
| Food / Drink / Bandages       |Warn me below this many. 0 turns the low warning off, running out always warns.                     |
| Show in chat / Show on screen |Where the warnings go.                                                                              |
| Remind at login               |The one reminder when you log in low. It only goes to chat, unless you've turned chat warnings off. |

| Buttons               |                                                             |
| --------------------- |------------------------------------------------------------ |
| Match action bar      |Copies the size and spacing of your main bar. On by default. |
| Button size / Spacing |Your own size, once you untick Match action bar.             |
| Stack vertically      |Buttons under each other instead of next to each other.      |
| Count size            |The number in the corner.                                    |
| Show buttons          |Hide them. Handy if you only use the macros.                 |
| Enable bandages       |Adds the bandage button. Off by default.                     |

The arrows next to the number boxes do 1 per click, 5 with shift, or just hold them down.

Setting a key binding is click, press a key, done. Right-click clears it. They also show up in the normal keybindings menu under AddOns.

For the macros, tick Make macros, then hit Eat, Drink, Both or Bandage to put one on your cursor and drop it on a bar. Unticking deletes them again.

Lost your buttons somewhere? `/snack reset` puts them back in the middle of the screen.

## Misc information

Should work on non-English clients too. If it does not, please let me know and I'll fix that!

Settings and bindings are shared between your characters. Pins and macros aren't.

## Changelog

### 0.3.0

- Bandages! Tick Enable bandages in `/snack` for a third button, with its own key binding and macro. Thanks to brucestarlove for adding them.
- No more empty gap where the drink button would be on characters without mana.

### 0.2.2

- Fixed clicking the buttons not eating or drinking. Sorry, that one was broken in 0.2.1.
- Now licensed under GPL-3.0.

### 0.2.1

- The buttons use the same frame as your action bars now.
- Light icons like Ice Cold Milk don't get a grey rim anymore.

### 0.2.0

- Mage food and water goes first, even before something you pinned.
- Mages get told when to conjure more.

### 0.1.0

- First release: eat and drink buttons, the hover list for pinning, low stock warnings, macros, key bindings and the settings menu.
