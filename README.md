<div align="center">

# 🏔️ Kathmandu Hiker 🏔️

### *The community trail companion for the Himalayas*

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20Storage-FFA000?logo=firebase&logoColor=white)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-success)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](#)

</div>

---

## 🌿 What it is

**Kathmandu Hiker** is a community-driven hiking app for the Kathmandu Valley and the surrounding Himalayan foothills. It blends **three things** into one product:

- 📍 **A crowdsourced trail guide** — anyone can submit a trail, admin approves
- 🛰️ **A live GPS hike tracker** — bus & car travel automatically filtered out
- 👥 **A small hiking social network** — friends, chats, group hikes

---

## 🎯 The problem it solves

Kathmandu has dozens of casual day-hikes — Shivapuri, Champadevi, Nagarjun, Phulchowki, Chandragiri — but the information is scattered across blogs, WhatsApp groups, and tribal knowledge. Hikers can't easily answer:

| Question | Why it matters |
|---|---|
| 🚌 How do I get there by local bus, and the fare? | Saves money + planning time |
| ⛰️ How hard is the climb, and is it crowded? | Avoid disappointment |
| 🌄 Where's that hidden viewpoint everyone mentions? | The good stuff |
| 🌦️ What's the weather like up there right now? | Stay safe |

This app collects all of that from the hikers who've actually walked the trail, and surfaces it cleanly to whoever heads there next. ✨

---

## 🙋 Who it's for

- 🏡 **Locals** planning a weekend escape
- 🎒 **Tourists** doing day hikes without a paid guide
- 📝 **Power hikers** who want to share routes and level up
- 👯 **Hiking groups** organising a weekend meetup

---

## 🚀 Key features

### 🏠 Home
Bento grid of trails, live weather ribbon, search, difficulty filter, bookmark, map view, and a **🚨 emergency SOS sheet** (Police `100`, Ambulance `102`, Tourist Police `1144`, GPS-SMS, built-in siren).

### 🥾 Trail Detail
Photo carousel with pinch-zoom, quick stats card, **🧭 Start Navigation** (Google Maps deep-link with 3-tier fallback), **📡 live GPS tracker**, *How to Get There* with real fares, **☁️ weather pill**, **📅 Plan Hike**, **🖼️ community gallery**, and **⭐ reviews with averaged ratings**.

### ➕ Add Trail (4-step flow)
1. **📷 Photos** — mandatory, multi-pick
2. **🥾 Difficulty** — Easy / Moderate / Hard / Challenging
3. **🚐 Transport** — start point, bus pickup, fare bracket, duration, searchable map
4. **✨ Experience** — rating, seasons, crowd, features, hazards, tips

### 👥 Social
- 🌍 **Community** — featured upcoming hikes + activity feed
- 💬 **Chats** — 1:1 messaging with unread badges
- 🤝 **Requests** — find hikers, send / cancel / accept friend requests

### 👤 Profile
Avatar, XP bar, hiker level, submissions, edit sheet, **🏆 achievements**, and **🛡️ admin dashboard** (admin role only).

---

## 🏅 Levels & XP

| XP | Action |
|---:|:---|
| 📝 **15** | Submit a trail |
| ✅ **80** | Trail approved by admin |
| ⭐ **10** | Post a review |
| 📸 **20** | Upload a community photo |
| 📅 **30** | Host a group hike |
| 🚶 **50** | Complete an Easy tracked hike |
| ⛰️ **100** | Complete a Moderate / Hard / Challenging hike |

**Title progression:**
🆕 New Hiker → 🌱 Beginner → 🚶 Trail Walker → 🧭 Pathfinder → 🏞️ Explorer → ⛰️ Mountain Guide → 👑 Trail Master

---

## 🎨 Design

- 🌲 **Forest-green primary**, moss-green dark accent
- 🅰️ **Lexend** typography across six tiers
- 🌙 **Dark mode by default**, full light/dark theming via Material 3
- ✨ Skeuomorphic shadows on primary buttons, sunken cards, hairline borders
- 🧗 Rugged but refined outdoor-gear feel

---

## 🛠️ Tech stack

| | |
|---|---|
| **Framework** | 💙 Flutter |
| **Backend** | 🔥 Cloud Firestore · 🔐 Firebase Auth · 📦 Firebase Storage |
| **Maps** | 🗺️ google_maps_flutter · 📍 geocoding |
| **Location** | 🛰️ geolocator (high-accuracy GPS) |
| **Integrations** | 🔗 url_launcher · ☁️ OpenWeather API |
| **Background** | 🔔 flutter_background_service · flutter_local_notifications |
| **UI** | 🖼️ cached_network_image · photo_view · google_fonts |

---

## 🧪 Smart hike tracking

Distance is only added to your hike when **all** of these are true for a GPS sample:

| Check | Rule | Why |
|---|---|---|
| 🎯 Accuracy | `≤ 30 m` | Drop weak GPS fixes |
| 📏 Move | `≥ 2 m` | Filter standing-still jitter |
| 🚫 Move | `≤ 80 m` | Reject phantom GPS jumps |
| 🐢 Speed | `≤ 8 km/h` | Ignore vehicle travel |

> 🚌 *That's why the bus you took to the trailhead doesn't pad your distance.*

---

## 💎 Why it's different

- 🇳🇵 **Built for Nepal** — NPR fare brackets, bus pickup info, Nepal SOS numbers (100/102/1144)
- 🏃 **Not a Strava clone** — community first, tracker second. No competitive leaderboard pressure.
- 📵 **Not a Facebook clone** — no algorithmic feed, no public timeline, no public posts
- 🌍 **Not an AllTrails clone** — every trail is hiker-submitted and admin-vetted, not scraped from open data

---

<div align="center">

### 🏔️ Made for the mountains, by the people who walk them. 🥾

</div>
