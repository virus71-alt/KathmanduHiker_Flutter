═══════════════════════════════════════════════════════════════
              🏔️  KATHMANDU HIKER  🏔️
   The community trail companion for the Himalayas
═══════════════════════════════════════════════════════════════


🌿 WHAT IT IS
─────────────
Kathmandu Hiker is a community-driven hiking app for the Kathmandu
Valley and the surrounding Himalayan foothills. It's three things
in one:

  📍  A crowdsourced trail guide   (anyone submits, admin approves)
  🛰️  A live GPS hike tracker      (bus & car travel auto-filtered)
  👥  A small hiking social network (friends, chats, group hikes)


🎯 THE PROBLEM
──────────────
Kathmandu has dozens of casual day-hikes — Shivapuri, Champadevi,
Nagarjun, Phulchowki, Chandragiri — but info is scattered across
blogs, WhatsApp groups and tribal knowledge. Hikers can't easily
answer:

  🚌  How do I get there by local bus, and the fare?
  ⛰️  How hard is the climb, and is it crowded?
  🌄  Where's that hidden viewpoint everyone mentions?
  🌦️  What's the weather like up there right now?

This app collects all of that from the hikers who've walked the
trail, and surfaces it cleanly to whoever heads there next.  ✨


🙋 WHO IT'S FOR
───────────────
🏡 Locals planning a weekend escape • 🎒 Tourists doing day hikes
without a paid guide • 📝 Power hikers who want to share routes
and level up • 👯 Groups organising a weekend meetup.


🚀 KEY FEATURES
───────────────

🏠  HOME  — Bento grid of trails, live weather ribbon, search,
    difficulty filter, bookmark, map view, 🚨 emergency SOS sheet
    (Police 100, Ambulance 102, Tourist Police 1144, GPS-SMS,
    built-in siren).

🥾  TRAIL DETAIL  — Photo carousel with pinch-zoom, quick stats,
    🧭 Start Navigation (Google Maps deep-link), 📡 live GPS
    tracker, How-to-Get-There with real fares, ☁️ weather pill,
    📅 Plan Hike, 🖼️ community gallery, ⭐ reviews with averaged
    ratings.

➕  ADD TRAIL  — 4-step flow:
    📷 Photos (mandatory) → 🥾 Difficulty → 🚐 Transport with
    searchable map + facilities → ✨ Experience (rating, seasons,
    crowd, features, hazards, tips).

👥  SOCIAL  — Three tabs:
    🌍 Community (upcoming hikes + activity feed),
    💬 Chats (1:1 messaging),
    🤝 Requests (find hikers, send/cancel/accept).

👤  PROFILE  — Avatar, XP bar, hiker level, submissions, edit
    sheet, 🏆 achievements, 🛡️ admin dashboard (admin role only).


🏅 LEVELS & XP
──────────────
   📝   15  submit a trail
   ✅   80  trail approved by admin
   ⭐   10  post a review
   📸   20  upload a community photo
   📅   30  host a group hike
   🚶   50  complete an Easy tracked hike
   ⛰️  100  complete a Moderate / Hard / Challenging hike

🆕 New Hiker → 🌱 Beginner → 🚶 Trail Walker → 🧭 Pathfinder →
🏞️ Explorer → ⛰️ Mountain Guide → 👑 Trail Master


🎨 DESIGN
─────────
🌲 Forest-green primary, moss-green dark accent • 🅰️ Lexend
throughout • 🌙 Dark mode by default • ✨ Skeuomorphic shadows on
primary buttons, sunken cards, hairline borders • 🧗 Rugged but
refined outdoor-gear feel.


🛠️ TECH STACK
─────────────
💙 Flutter  •  🔥 Cloud Firestore  •  🔐 Firebase Auth
📦 Firebase Storage  •  🗺️ Google Maps  •  📍 geocoding
🛰️ geolocator (high-accuracy GPS)  •  🔗 url_launcher
🔔 background_service + local_notifications  •  ☁️ OpenWeather


🧪 SMART HIKE TRACKING
──────────────────────
Distance is only added to your hike when ALL of these are true:

   🎯  Accuracy ≤ 30 m            (drop weak GPS fixes)
   📏  Move    ≥ 2 m              (filter standing-still jitter)
   🚫  Move    ≤ 80 m             (reject phantom jumps)
   🐢  Speed   ≤ 8 km/h           (ignores vehicle travel)

🚌 That's why the bus you took to the trailhead doesn't pad your
   distance.


💎 WHY IT'S DIFFERENT
─────────────────────
🇳🇵  Built for Nepal — NPR fares, bus pickups, Nepal SOS numbers.
🏃  Not a Strava clone — community first, tracker second, no
    leaderboard pressure.
📵  Not a Facebook clone — no algorithmic feed, no public posts.
🌍  Not an AllTrails clone — every trail is hiker-submitted and
    admin-vetted, not scraped.


═══════════════════════════════════════════════════════════════
   🏔️  Made for the mountains, by the people who walk them.  🥾
═══════════════════════════════════════════════════════════════
