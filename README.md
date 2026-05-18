<div align="center">

# Yama

### *Modern outdoor social platform — hiking, trekking & trip planning*

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20Storage-FFA000?logo=firebase&logoColor=white)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-success)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](#)

</div>

---

## What it is

**Yama** is an outdoor social platform built for the Himalayas. It brings together trail discovery, live GPS tracking, social coordination, and trip planning into one premium, dark-first experience.

- **Trail guide** — crowdsourced, admin-vetted trails with transport, fares, and conditions
- **GPS hike tracker** — vehicle travel automatically filtered out; XP earned per hike
- **Social layer** — friends, 1:1 chat, group hikes, activity feed
- **Journey Builder** — multi-leg trip planning with transport modes, fare ranges, and map routing

---

## The problem it solves

Kathmandu has dozens of day-hikes — Shivapuri, Champadevi, Nagarjun, Phulchowki, Chandragiri — but the information is scattered across blogs, WhatsApp groups, and word of mouth.

| Question | Why it matters |
|---|---|
| How do I get there by local bus, and what's the fare? | Saves money and planning time |
| How hard is the climb, and is it crowded today? | Avoid disappointment |
| What's the weather like right now at the summit? | Stay safe |
| Who else is going this weekend? | Find your group |

Yama collects all of this from hikers who have actually walked the trail, and surfaces it clearly to whoever heads there next.

---

## Who it's for

- **Locals** planning a weekend escape from the city
- **Tourists** doing day hikes without a paid guide
- **Experienced hikers** who want to share routes and track progress
- **Hiking groups** coordinating a weekend meetup

---

## Key features

### Home
Trail grid with live weather, search, difficulty filter, bookmarks, and an emergency SOS sheet (Police 100, Ambulance 102, Tourist Police 1144, GPS-SMS, built-in siren).

### Trail Detail
Photo carousel, quick stats, GPS navigation deep-link, live hike tracker, transport guide with fares, weather, group hike planning, community gallery, and star reviews.

### Journey Builder
Structured multi-leg trip planner. Each leg has a transport mode (Bus / Taxi / Walk / Bike), from/to with Places autocomplete, fare range, and duration. The full route renders on a map.

### Add Trail
Four-step submission flow: photos → difficulty → transport → experience. Admin approval gates public listing.

### Social
Community activity feed, 1:1 chat with unread badges, friend requests (send / cancel / accept / reject), and hiker discovery.

### Profile
XP bar, hiker level, submissions list, edit sheet, achievements screen, and admin dashboard (admin role only).

---

## XP & levels

| XP | Action |
|---:|:---|
| 15 | Submit a trail |
| 80 | Trail approved by admin |
| 10 | Post a review |
| 20 | Upload a community photo |
| 30 | Host a group hike |
| 50 | Complete an easy tracked hike |
| 100 | Complete a moderate / hard / challenging hike |

Level titles: New Hiker → Beginner → Trail Walker → Pathfinder → Explorer → Mountain Guide → Trail Master

---

## Tech stack

| | |
|---|---|
| **Framework** | Flutter 3.22+ |
| **State** | Riverpod 2.x + clean architecture (domain / data / feature layers) |
| **Backend** | Cloud Firestore · Firebase Auth · Firebase Storage |
| **Offline** | Drift SQLite outbox (write queue with exponential-backoff retry) |
| **Routing** | go_router with typed routes and StatefulShellRoute |
| **Maps** | google_maps_flutter · Places SDK |
| **Location** | geolocator (high-accuracy GPS) |
| **Monitoring** | Firebase Crashlytics · Firebase Performance · Firebase Analytics |
| **UI** | cached_network_image · photo_view · google_fonts |

---

## Architecture

```
lib/
  core/          logger, analytics, errors, theme
  domain/        entities, repository interfaces, use cases
  data/          Firestore DTOs, sources, repository impls
  state/         Riverpod providers
  router/        go_router config
  features/      home/, trail/, social/, profile/, auth/
  services/      HikeTrackingService, RemoteConfigService
  widgets/       cross-feature widgets
```

All repository methods return `Either<Failure, T>`. Streams surface errors through Riverpod's error state. The offline outbox queues writes that must survive connectivity loss.

---

## Smart hike tracking

Distance is only added when **all** of these are true for a GPS sample:

| Check | Rule | Why |
|---|---|---|
| Accuracy | ≤ 30 m | Drop weak fixes |
| Min move | ≥ 2 m | Filter standing-still jitter |
| Max move | ≤ 80 m | Reject phantom GPS jumps |
| Speed | ≤ 8 km/h | Ignore vehicle travel |

---

<div align="center">

*Built for the mountains, by the people who walk them.*

</div>
