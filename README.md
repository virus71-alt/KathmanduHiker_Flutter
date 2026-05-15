────────────────────────────────────────────────────────────────────
                  🏔️  KATHMANDU HIKER  🏔️
       The community trail companion for the Himalayas
────────────────────────────────────────────────────────────────────


🌿 WHAT IS IT
─────────────

Kathmandu Hiker is a community-driven hiking and trail discovery app
focused on the Kathmandu Valley and the surrounding Himalayan
foothills. It blends three things into one product:

  1.  📍  A crowdsourced trail guide  — anyone can submit a trail
      with photos, route, public-bus fare, difficulty, hidden spots
      and hard sections. Submissions go through admin approval
      before they show up to the rest of the community.

  2.  🛰️  A live GPS hike tracker  — track your hike in real time
      with smart filtering that ignores bus, car and motorbike
      segments (anything moving faster than ~8 km/h is dropped) so
      only genuine on-foot distance counts.

  3.  👥  A small hiking social network  — connect with other
      trekkers, send friend requests, chat one-on-one, plan group
      hikes, review trails, and share community photos.


🎯 THE PROBLEM IT SOLVES
────────────────────────

Kathmandu has dozens of casual day-hike trails — Shivapuri, Champadevi,
Nagarjun, Phulchowki, Chandragiri — but the information for each is
scattered across blogs, WhatsApp groups, Instagram reels and tribal
knowledge. Tourists and locals both struggle to answer simple
questions:

  •  🚌  How do I get there by local bus, and what's the fare?
  •  🛡️  Is it safe? Is it crowded on weekends?
  •  🌄  Where's the hidden viewpoint everyone talks about?
  •  ⛰️  How hard is the climb — am I prepared for it?
  •  🌦️  What's the weather like up there right now?

Kathmandu Hiker collects all of this from the hikers who've actually
walked the trail, then surfaces it cleanly to anyone heading there
next.  ✨


🙋 WHO IT'S FOR
───────────────

  •  🏡  Locals  looking for a weekend escape from the valley.
  •  🎒  Tourists  who want to do day hikes around Kathmandu
     without hiring an expensive guide.
  •  📝  Trail authors / power hikers  who want to share routes
     and earn XP / level up as recognition.
  •  👯  Hiking groups  organising a meetup on a specific weekend.


🚀 WHAT YOU CAN DO IN THE APP
─────────────────────────────

  🏠  HOME
  •   Browse all approved trails as a bento grid of cards
  •   🌤️  Live weather ribbon for Kathmandu at the top
  •   🔍  Search trails by name or location
  •   🎚️  Filter by difficulty — Easy / Moderate / Hard /
       Challenging
  •   🔖  Save / unsave a trail with the bookmark icon
  •   🗺️  Map view of every trail pinned over the Kathmandu valley
  •   🚨  Emergency SOS sheet — Police, Ambulance, Tourist Police,
       GPS-SMS, and a built-in siren that uses the phone's alarm
       tone

  🥾  TRAIL DETAIL
  •   📸  Hero photo carousel with pinch-to-zoom full-screen viewer
  •   📊  Quick stats card (Duration, Cost, Travel Mode)
  •   🧭  "Start Navigation" deep-links directly to Google Maps
       walking directions with a three-tier fallback so it works
       on any device
  •   🔖  Bookmark with one tap, mirrors back to Saved tab
  •   📡  Live GPS hike tracker — start, watch live km, end &
       claim XP
  •   📋  Trail Details grid (Difficulty, Cost, Mode, Pickup,
       Duration)
  •   💬  Shared Experiences card (Best Seasons, Crowd Level,
       Hidden Spot, Difficult Part — auto-parsed from the
       AddTrail form)
  •   🚌  How to Get There rail with real fare data
  •   ☁️  Weather pill with current temp + condition
  •   📅  Plan Hike — create a group event with date + max
       attendees, notifies all your friends
  •   🖼️  Trail photo gallery, with community-uploaded photos
       mixed in
  •   ⭐  Reviews — five-star rating slider, italic review cards;
       the aggregate rating averages the author's seed + every
       review

  ➕  ADD TRAIL  (4-step PageView)
  •   📷  Photos  — multi-pick, at least one required
  •   🥾  Difficulty  — four vertical cards (Easy / Moderate /
       Hard / Challenging) with watermark icons
  •   🚐  Transport details  — start point, bus pickup, fare
       bracket, duration, searchable Google Map with text-to-pin
       geocoding, facilities multi-select
  •   ✨  Final details  — overall rating, best seasons, crowd
       level, notable features and hazards as multi-select chips
       (with exclusive "None" options), Quick Tips textarea

  👥  SOCIAL  (Community / Chats / Requests)
  •   🌍  Community — featured upcoming hikes carousel + Recent
       Activity feed (with a Clear button)
  •   💬  Chats — friend list with avatar, last message preview,
       online indicator, unread badge
  •   🤝  Requests — search hikers by name, send / cancel /
       accept friend requests with proper Sent state, pending
       requests with Accept and Decline buttons

  👤  PROFILE
  •   🖼️  Avatar, name, XP bar, hiker level
  •   📥  Approved + pending submissions tabs
  •   ✏️  Edit profile sheet
  •   🏆  Achievements gallery
  •   🛡️  Admin dashboard (for admin role only)
  •   🚪  Sign out

  🏅  ACHIEVEMENTS
  •   🎚️  Hiker level progression (1–100)
  •   📜  Titles:
       🆕 New Hiker →
       🌱 Beginner →
       🚶 Trail Walker →
       🧭 Pathfinder →
       🏞️ Explorer →
       ⛰️ Mountain Guide →
       👑 Trail Master
  •   ✨  XP awarded for submitting / having a trail approved /
       posting a review / sharing a community photo / hosting a
       group hike / completing tracked hikes


⚡ XP RULES  (lib/utils/ranking_manager.dart)
────────────────────────────────────────────

  📝   15  submitting a trail
  ✅   80  having your trail approved by admin
  ⭐   10  posting a review
  📸   20  uploading a community photo
  📅   30  hosting a group hike
  🚶   50  completing a tracked hike on an Easy trail
  ⛰️  100  completing a tracked hike on Moderate / Hard /
           Challenging

  💯 100 XP per level. 100 levels max.


🎨 DESIGN SYSTEM
────────────────

  •  🌲  Forest-green primary, moss-green accent in dark mode
  •  🅰️  Lexend typography everywhere, six tiers
  •  🎭  Material 3 token-based theme with full light + dark mode
  •  🌙  Default theme on first launch:  dark
  •  ✨  Skeuomorphic shadows on primary buttons, sunken inset
        shadows on read-only cards, hairline outline borders
  •  🧗  Premium outdoor-gear aesthetic — rugged but refined


🛠️ TECH STACK
─────────────

  •  💙  Flutter            — single codebase for Android + iOS
  •  🔐  Firebase Auth      — email/password authentication
  •  🔥  Cloud Firestore    — trails, users, reviews, events,
                              chats, notifications, activity feed
  •  📦  Firebase Storage   — trail photos, profile pictures,
                              gallery
  •  🗺️  google_maps_flutter — location picker + map view
  •  📍  geocoding          — text-to-pin location search
  •  🛰️  geolocator          — high-accuracy GPS hike tracking
  •  🔗  url_launcher       — Google Maps deep-linking + SOS
                              dialing
  •  🖼️  cached_network_image, photo_view — galleries and zoom
                              viewer
  •  🔔  flutter_local_notifications, flutter_background_service
                            — background hike tracking
  •  🅰️  google_fonts       — Lexend
  •  💾  shared_preferences — theme persistence
  •  ☁️  OpenWeather API    — current trail weather


🧪 HIKE TRACKING ALGORITHM
──────────────────────────

A foreground high-accuracy GPS stream accumulates distance only when
ALL of these are true for a sample:

  1.  🎯  pos.accuracy  ≤  30 m         (drop weak fixes)
  2.  📏  delta         ≥  2 m          (filter standing-still
                                         jitter)
  3.  🚫  delta         ≤  80 m         (reject phantom GPS jumps)
  4.  🐢  speed         ≤  2.22 m/s     (≈ 8 km/h — ignores
                                         vehicles)

🚌 This is what stops the bus you took to the trailhead from
counting as part of your hike.


💎 WHY IT FEELS DIFFERENT
─────────────────────────

  •  🇳🇵  Built specifically for Nepal — fare brackets in NPR,
        bus pickup info, monsoon season awareness, SOS calls
        Nepal's 100 / 102 / 1144.
  •  🏃  Not a Strava clone — no leaderboard, no competitive
        layer. It's a community first, a tracker second.
  •  📵  Not a Facebook clone — no public timeline, no public
        posts, no algorithmic feed. Just trails, reviews, and
        friends.
  •  🌍  Not an AllTrails clone — every trail is community-
        submitted and admin-vetted, not scraped from open data.


────────────────────────────────────────────────────────────────────
   🏔️  Made for the mountains, by the people who walk them.  🥾
────────────────────────────────────────────────────────────────────
