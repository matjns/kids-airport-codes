# Airport Codes

Airport Codes is a small Mac app for kids about 8 to 13. Every airport has a 3-letter code on its luggage tags and departure boards: SEA, LAX, JFK, LHR. This game teaches the real ones.

- **Find the code**: the board shows a city and its airport. Type the 3 letters.
- **Where does it go?**: the board flips to a code. Pick the city (Easy and Medium) or type it (Advanced).
- **Mixed**: both kinds.

Hints: the first hint gives the first letter of the code (or the country), the second gives two letters (or "The city is S_______"). A right answer with no hints is worth 3 stars, 2 with one hint, 1 with two. Streaks count right answers in a row, and every code you get right goes into your "codes collected".

After each answer you may get a true **"Why is it called that?"** story: ORD is from Orchard Field, MCO from McCoy Air Force Base, MSY from the Moisant Stock Yards, LAX got its X when codes went from two letters to three, Canadian codes start with Y, and more (46 in all, in `Data/facts.txt`).

If you type a different real code, the app tells you which airport that one is (for example, LGA is also in New York).

## Levels go up on their own

There is no level picker. Everyone starts on **Easy**: 40 big hubs like SEA, LAX, JFK, LHR, CDG, and HND. Get 8 of your last 10 right and you level up to **Medium** (151 more airports, and the wrong choices come from the same country), then **Advanced** (415 more airports all over the world, and you type the city). Each level up gets a big "Now boarding!" moment. If someone misses almost every question for a while (2 or fewer right out of 10), the app gently steps back one level. Answers that used both hints still earn a star but don't count toward leveling up. The level is remembered between launches.

## Grown-ups screen

Press and hold the **Airport Codes** title on the home screen for 3 seconds, then answer a multiplication question. From there you can set the level or reset progress.

## Data and credits

- Airport codes, names, and countries: **OurAirports** (https://ourairports.com/data/), public domain. `Data/generate.py` keeps only airports that OurAirports lists as large or medium, with scheduled passenger service and a 3-letter IATA code, so every code in the game is checked against that list. Codes that fail the check are skipped and printed.
- The tier lists (`Data/tiers.txt`), friendlier city names (`Data/names.txt`), and code stories (`Data/facts.txt`) were written for this app.

To rebuild after editing: download `airports.csv` and `countries.csv` from OurAirports into a folder and run `python3 Data/generate.py <that folder>`. It rewrites `Sources/AirportCodesCore/AirportData.swift`.

## Download and install

Not released yet. When a release exists it will be on https://github.com/matjns/kids-airport-codes/releases as `AirportCodes-mac-universal.zip`. It runs on Apple silicon and Intel, and needs macOS 14 or later. It is not signed with an Apple Developer ID, so macOS warns the first time you open it. The steps are in `README-mac.txt`.

Put `Airport Codes.app` in `/Applications`.

## Kids Computer

The Kids Computer launcher (https://github.com/matjns/kids-computer) can open it with the bundle id `com.kidscomputer.airportcodes`. Command-Q quits, and closing the window quits too, so the launcher comes back.

## Privacy

No network, no accounts, no ads, no links out. Progress (`progress.json`) stays in the app's Application Support folder on this Mac.

## Build it yourself

You need a Mac with macOS 14 or later and Xcode 15 or later.

```bash
./build.sh test
./build.sh
```

`./build.sh test` runs the dataset, answer-checking, question, and level tests (also on Linux, anywhere Swift is installed). `./build.sh` writes `build/Airport Codes.app` and `dist/AirportCodes-mac-universal.zip`.

The airport list, answer checking, questions, and levels live in `AirportCodesCore`. The window and departure board are the `AirportCodes` target.

What is left before an App Store submission is in `docs/APP_STORE.md`.

## License

MIT. See `LICENSE`. The OurAirports data is public domain.
