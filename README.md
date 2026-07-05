# 🥗 AI Macro Tracker MVP

A lightning-fast, AI-powered macro and weight tracking application built entirely in **one day**. 

Designed to remove the friction of traditional calorie counting, this MVP leverages multimodal AI to automatically estimate macronutrients (Proteins, Carbs, Fats) and calories directly from text descriptions or photos of your meals. Built for rapid, everyday use, especially useful for strictly managing transitions between bulk and cut phases without spending minutes manually logging ingredients.

## ⚡ 1-Day Build Journey
This project was conceptualized, designed, and deployed in a single day to prove the viability of a frictionless tracking system. The goal was to go from zero to a fully functional mobile MVP integrating hardware features (camera), a remote relational database, and an LLM API.

## 🚀 Features

* **AI Meal Logging (Text & Image):** Take a photo of your plate or describe it (e.g., "150g chicken breast and a cup of rice"), and the app instantly parses it into strict nutritional data.
* **Saved Foods:** Save frequent meals to favorites for instant logging without hitting the API.
* **Daily Dashboard:** Visual summary of your daily intake vs. macro goals.
* **Weight Tracking:** Daily log to correlate body weight with caloric intake.
* **Cross-Device Sync:** Cloud database ensures data is updated in real-time across devices.

## 🛠️ Tech Stack

* **Frontend:** Flutter (Dart) - Chosen for rapid mobile iteration and native camera handling.
* **Backend & Database:** Supabase (PostgreSQL) - Structured with independent tables for `profiles`, `macro_goals`, `meals`, and `weight_logs` (using compound unique constraints).
* **AI Processing:** Google Gemini API (`gemini-1.5-flash`) - Used via multimodal prompts strictly formatted to return JSON payloads.

## 🏗️ Architecture Setup
* **Data Layer:** Interacts with Supabase for CRUD operations and Gemini API for unstructured-to-structured data conversion.
* **Presentation Layer:** Clean Material 3 UI focusing on large touch targets and quick actions for on-the-go logging.

## 🏃‍♂️ How to Run Locally

1. Clone this repository.
2. Run `flutter pub get` to install dependencies.
3. Configure your environment variables for `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `GEMINI_API_KEY`.
4. Run the project: `flutter run`
