# Technical Specification: La Roulette Magique (Windows / Python)

## 1. Executive Summary & Tech Stack

* **Operating System:** Windows (Targeting Full Screen Native Resolution)
* **Control:** Mouse (Left Click)
* **Core Language:** Python 3.10+
* **Framework:** `pygame-ce` (Pygame Community Edition)
  * Hardware-accelerated 2D rendering for fluid 60 FPS transitions.
  * Native full-screen mode (`pygame.FULLSCREEN | pygame.SCALED`).
  * Low-latency multi-channel audio mixer (`pygame.mixer`).
* **TTS Engine:** Gemini 3.8 Flash TTS (`gemini-3.8-flash-tts` / Google Cloud Vertex AI & Text-to-Speech API).
  * Account / Project: `martin.luka.ringring@gmail.com` / `project-16e6ffba-6527-45d1-a6c`.
  * Encoded to MP3 at 192 kbps (44.1 kHz).
  * Pre-generates all audio offline to eliminate runtime API latency and network dependency.
* **Portability & Distribution:** Bundled into a zero-dependency standalone Windows executable: `les_cartes_magiques.exe` in `dist/les_cartes_magiques/`.
* **Application Icon:** Custom multi-resolution icon (`assets/images/icons/app_icon.ico` and `.png`) featuring three overlapping cards rotated relative to one another (left tilted card 'A', right tilted card '1', and center card with golden magic star '★').

---

## 2. Audio & Speech Architecture (Flash Audio)

### 2.1 Voice Personas & Model Mapping
* **French Voice Personas:**
  * **Female (`Aoede`):** Warm, encouraging French preschool teacher (*institutrice*). Stored in `assets/audio/voice_female/` (or `assets/audio/fr/voice_female/`).
  * **Male (`Puck`):** Gentle, friendly French male teacher (*instituteur*). Stored in `assets/audio/voice_male/` (or `assets/audio/fr/voice_male/`).
* **English Voice Personas:**
  * **Female (`Kore`):** Warm, clear, cheerful English preschool teacher. Stored in `assets/audio/en/voice_female/`.
  * **Male (`Fenrir`):** Energetic, clear, supportive English male teacher. Stored in `assets/audio/en/voice_male/`.
* **Score Animal Sounds (Result Screen Mascot Audio):**
  * **French Mascot Clips:** Stored in `assets/audio/animals/fr/score_0_ant.mp3` through `score_10_bear.mp3`.
  * **English Mascot Clips:** Stored in `assets/audio/animals/en/score_0_ant.mp3` through `score_10_bear.mp3`.
  * **Dual-Language Picking:** When both languages are enabled in Configuration, reward audio randomly picks between French and English per victory screen.
* **Audio Format:** High-quality MP3 at 192 kbps, 44.1 kHz mono (`-ar 44100 -b:a 192k`).

### 2.2 Score Mascot Audio & Subtitles Matrix

| Score | Mascot | FR Voice | Spoken French Audio | EN Voice | Spoken English Audio | Audio File |
| :---: | :--- | :---: | :--- | :---: | :--- | :--- |
| **0** | **Fourmi** *(Ant)* | `Aoede` | `"Hop, hop ! Courage, réessaie !"` | `Kore` | `"Hop, hop ! Don't give up, try again !"` | `score_0_ant.mp3` |
| **1** | **Mouche** *(Fly)* | `Aoede` | `"Bzz, bzz ! Continue, tu peux le faire !"` | `Kore` | `"Bzz, bzz ! Keep going, you can do it !"` | `score_1_fly.mp3` |
| **2** | **Grenouille** *(Frog)* | `Puck` | `"Coâ, coâ ! C'est un bon début !"` | `Fenrir` | `"Ribbit, ribbit ! That's a good start !"` | `score_2_frog.mp3` |
| **3** | **Canard** *(Duck)* | `Aoede` | `"Coin, coin ! Tu apprends vite !"` | `Kore` | `"Quack, quack ! You're learning fast !"` | `score_3_duck.mp3` |
| **4** | **Lapin** *(Bunny)* | `Aoede` | `"Hop, hop ! Continue comme ça !"` | `Kore` | `"Hop, hop ! Keep it up, you're doing great !"` | `score_4_bunny.mp3` |
| **5** | **Chat** *(Cat)* | `Aoede` | `"Miaou, miaou ! C'est super !"` | `Kore` | `"Meow, meow ! That's wonderful !"` | `score_5_cat.mp3` |
| **6** | **Chien** *(Dog)* | `Puck` | `"Ouaf, ouaf ! Tu y es presque !"` | `Fenrir` | `"Woof, woof ! You're getting there !"` | `score_6_dog.mp3` |
| **7** | **Renard** *(Fox)* | `Puck` | `"Yap, yap ! Bien joué, petit malin !"` | `Fenrir` | `"Yap, yap ! Well played, clever one !"` | `score_7_fox.mp3` |
| **8** | **Mouton** *(Sheep)* | `Aoede` | `"Bêê, bêê ! Formidable !"` | `Kore` | `"Baa, baa ! Fantastic work !"` | `score_8_sheep.mp3` |
| **9** | **Lion** *(Lion)* | `Puck` | `"Rroarrr ! Très bien !"` | `Fenrir` | `"Roarrr ! Very good !"` | `score_9_lion.mp3` |
| **10** | **Ours** *(Bear)* | `Puck` | `"Grroaar ! Parfait !"` | `Fenrir` | `"Grroaar ! Perfect !"` | `score_10_bear.mp3` |

### 2.3 Emotion & Prompt Prompting Matrix
Audio files are generated offline via an automated Python batch script. Prompts include delivery instructions to steer vocal expression:

| Type | Instruction / Prosody Guidance | French Spoken Text | File Naming Convention |
| :--- | :--- | :--- | :--- |
| **Question (Letter)** | *Warm, curious, inviting teacher tone* | `"Où est la lettre {symbol} ?"` | `q_letter_{symbol}.mp3` |
| **Question (Number)** | *Warm, curious, inviting teacher tone* | `"Où est le chiffre {symbol} ?"` | `q_number_{symbol}.mp3` |
| **Correct Confirmation** | *Extremely happy, enthusiastic, celebratory* | `"Oui, c'est la lettre {symbol} !"` / `"Oui, c'est le chiffre {symbol} !"` | `ans_pos_{type}_{symbol}.mp3` |
| **Wrong Feedback** | *Gentle, sympathetic, slightly sad but encouraging* | `"Non, c'est la lettre {symbol}."` / `"Non, c'est le chiffre {symbol}."` | `ans_neg_{type}_{symbol}.mp3` |

#### 2.3.1 Strict French Pronunciation Enforcement
> [!IMPORTANT]
> **Gemini Flash TTS English Loanword Pitfall:**
> When generating audio for French words that also exist as loanwords in English (e.g., *"parfait"*, *"super"*), Gemini 3.8 Flash TTS defaults to American English phonetics (e.g. `/pɑːrˈfeɪ/` instead of `/paʁ.fɛ/`) if the style prompt is written in English or lacks an explicit French phonetic directive.
> 
> **Enforcement Contract:**
> 1. All French style prompts must pass `validate_french_style_prompt()` from `src/tts_generator.py` (which strictly requires explicit French language markers, e.g. `"Voix en français. Prononciation française authentique et naturelle..."`).
> 2. Helper `build_french_style_prompt()` must be used to wrap prompt descriptions.
> 3. Words prone to American phonetic confusion (like *"Parfait"*) must include explicit phonetic disambiguation in the prompt: `"Prononciation française soignée du mot « Parfait » avec le son 'è' /paʁfɛ/ et r français, jamais à l'américaine."`

### 2.4 Audio Playback Pipeline
* **Sound Effects (SFX):**
  * **Correct Click:** Playful bright chime / xylophone glissando (`sfx_correct.wav`).
  * **Wrong Click:** Soft low wooden thud / gentle "boing" (`sfx_wrong.wav`). Never use harsh buzzers.
* **Audio Sequencing:** When a card is clicked, play the SFX immediately on Channel 0, followed immediately (or overlapped by 150ms) by the corresponding voice feedback on Channel 1.

---

## 3. Game Flow & Logic

### 3.1 Structure & Difficulty Progression
* Exactly **10 rounds** per session.
* Total items presented on screen per round:
  * **Rounds 1–4:** 3 symbols
  * **Rounds 5–7:** 4 symbols
  * **Rounds 8–10:** 5 symbols

### 3.2 Round Lifecycle
1. **Target Selection:** Pick one target symbol $T$ at random from the active configuration pool.
2. **Distractor Selection:** Randomly pick $N - 1$ unique distractors from the remaining active pool.
   * *Rule:* All $N$ symbols displayed in any given round must be strictly unique.
3. **Voice Assignment:** Randomly assign either Voice 1 (Female) or Voice 2 (Male) to the round.
4. **Fly-in Phase:** Symbols animate in rapidly from the left edge.
5. **Prompt Playback:** Voice plays question prompt: *"Où est la lettre/le chiffre [T] ?"*.
6. **Interaction Loop:**
   * **If Child Clicks Correct Target:**
     * Play `sfx_correct.wav`.
     * Card triggers **Rainbow Flashing Effect**.
     * Play enthusiastic voice confirmation: *"Oui, c'est la lettre/le chiffre [T] !"*.
     * If this was the first attempt of the round: **Score increases by 1**.
     * Wait for voice to finish, then proceed to Fly-out Phase.
   * **If Child Clicks Wrong Symbol:**
     * Play `sfx_wrong.wav`.
     * Card triggers **Red Flash Effect**.
     * Play sympathetic voice feedback: *"Non, c'est la lettre/le chiffre [Clicked] !"*.
     * **Forfeit round score:** Mark current round as failed (0 points awarded).
     * **Enforce completion:** The round remains active; the child must keep guessing until the correct target is clicked.
7. **Fly-out Phase:** All symbols slide out to the right edge.
8. **Next Round / Game Over:** If round = 10, transition to Score Screen.

---

## 4. Visual Design & Animation Specs

* **Background:** Solid Pure White (`#FFFFFF`).
* **Text / Symbols:**
  * Font Variety: Uses a rotating pool of standard built-in Windows fonts to bring visual variety and reinforce symbol recognition across different typefaces (`Segoe UI`, `Comic Sans MS`, `Calibri`, `Verdana`, `Trebuchet MS`).
  * Color: Deep Charcoal / Navy (`#222222`) on default state for maximum readability.
  * Size: Extra large (occupying ~50–65% of the card height).
* **Controls & Navigation:**
  * Mouse: Left Click on cards and UI buttons.
  * Keyboard: `ESC` returns to the Main Menu from any active game or configuration screen, or exits the game when pressed on the Main Menu.
* **Card Fly-in Animation:**
  * Initial position: Off-screen left (`x < -width`).
  * Target position: Equidistant horizontal distribution centered on the screen.
  * Sequence: Staggered entry (delay of 0.08s between cards).
  * Total duration: strictly under 1.0 second.
  * Curve: Ease-out cubic.
* **Selection Effects:**
  * **Rainbow Flash (Correct):** Modulate card border/glyph hue across the HSV spectrum ($0^\circ \to 360^\circ$) over 0.8 seconds.
  * **Red Flash (Incorrect):** Tint card background/symbol bright red (`#FF4D4D`) with a quick fade back to neutral (0.4 seconds).
* **Card Fly-out Animation:**
  * Final position: Off-screen right (`x > screen_width`).
  * Staggered sequential exit under 0.8 seconds.

---

## 5. UI Architecture & Screens

### 5.1 Main Screen
* Full-screen presentation.
* Minimalist layout:
  * Game Title: *"Apprenons les Lettres et les Chiffres !"*
  * Button 1: **Jouer (Play)** (Large, colorful, easy target).
  * Button 2: **Configuration (Options)** (Gear icon / secondary button).

### 5.2 Configuration Screen
* Checkbox grid to select which symbols appear in gameplay:
  * **Uppercase Letters:** 26 checkboxes (`A` to `Z`).
  * **Lowercase Letters:** 26 checkboxes (`a` to `z`).
  * **Numbers:** 20 checkboxes (`1` to `20`).
* **Default Active Pool:**
  * Numbers: `1, 2, 3, 4, 5, 6`
  * Letters: `A, O, U, I, E`
* **Validation:** Requires at least 5 total symbols selected to enable the "Save / Play" action (preventing round 8–10 setup failure).
* **Persistence:** Selections saved locally to `config.json`.

### 5.3 Score Screen (Results Screen)
* Displayed immediately after completing Round 10.
* **Progress Stars:**
  * 10 Unicode stars (`★` / `☆`) representing each round's outcome:
    * Correct answer: Golden yellow filled star `★` (`RGB(235, 165, 0)`).
    * Wrong attempt: Empty star `☆` (`RGB(20, 20, 25)`).
  * **Falling Animation:** Stars start above the top edge of the screen and drop down into place using an ease-out cubic curve (duration $\le 0.45$s).
* **Score Mascot Animal:**
  * Visual representation of score (0: Ant, 1: Fly, 2: Frog, 3: Duck, 4: Bunny, 5: Cat, 6: Dog, 7: Fox, 8: Sheep, 9: Lion, 10: Bear).
  * **Size:** Rendered at twice the previous size (`520px` scaled, occupying screen center).
  * **Fade-In:** Smooth alpha fade from 0 to 255 over $\le 0.45$s.
  * **Audio Reward:** Triggers matching animal sound clip ($\le 2.0$s) via `AudioManager.play_animal_sound(score)`.
* **Play Button:**
  * Centered beneath the animal illustration (`▶` icon).
  * Sized compactly (`95px` scaled).
  * Quick fade-in over $\le 0.4$s.
* **Animation Timing Guarantee:** All entrance fades and drop animations complete strictly within 0.5s.

---

## 6. Directory Structure

```text
french_learner/
├── assets/
│   ├── audio/
│   │   ├── sfx/
│   │   │   ├── correct.wav
│   │   │   └── wrong.wav
│   │   ├── voice_female/
│   │   │   ├── q_letter_A.mp3
│   │   │   ├── ans_pos_letter_A.mp3
│   │   │   ├── ans_neg_letter_A.mp3
│   │   │   └── ...
│   │   └── voice_male/
│   │       ├── q_letter_A.mp3
│   │       ├── ans_pos_letter_A.mp3
│   │       ├── ans_neg_letter_A.mp3
│   │       └── ...
│   └── fonts/
│       └── Lexend-Bold.ttf
├── config.json               # Persisted checkbox states
├── scripts/
│   ├── generate_all_audio.py # Batch generator for all game audio
│   └── generate_voice_samples.py
├── src/
│   └── tts_generator.py      # Core Gemini 3.8 Flash TTS synthesis module
├── tests/                    # Pytest test suite
├── main.py                   # Game loop, UI screens, animations
└── requirements.txt          # pygame-ce, google-genai, requests, google-auth

---

## 7. Appendix: Audio Generation Guide

### 7.1 Overview & Authentication
All voice files are synthesized offline using **Gemini 3.8 Flash TTS** via Google Cloud Vertex AI REST API and converted to MP3 at 192 kbps (44.1 kHz mono) with FFmpeg.
* **Google Cloud Project:** `project-16e6ffba-6527-45d1-a6c`
* **Account:** `martin.luka.ringring@gmail.com`
* **Authentication:** Uses Google Cloud Application Default Credentials (ADC):
  ```bash
  gcloud auth application-default login
  gcloud config set project project-16e6ffba-6527-45d1-a6c
  ```

### 7.2 Generating the Entire Audio Batch
To generate or update all standard in-game audio files (138 female files + 138 male files = 276 files total, plus SFX copies):
```bash
python scripts/generate_all_audio.py
```
* The script is **idempotent and resumable**: files already generated with size > 1 KB are automatically skipped.
* Output destinations:
  * `assets/audio/voice_female/`
  * `assets/audio/voice_male/`
  * `assets/audio/sfx/`

### 7.3 Generating Single or Custom Audio Files (Python API)
To generate arbitrary new audio files programmatically, import and invoke `synthesize_speech` from `src/tts_generator.py`:

```python
from pathlib import Path
from src.tts_generator import TTSRequest, synthesize_speech

request = TTSRequest(
    text="Bravo, tu as terminé tous les niveaux !",
    output_path=Path("assets/audio/voice_female/bravo_end.mp3"),
    voice_name="Aoede",  # Use "Aoede" for female or "Puck" for male
    style_prompt=(
        "Voix en français. Voix féminine d'institutrice, extrêmement joyeuse, "
        "fière et chaleureuse pour un jeune enfant. Prononciation claire et distincte."
    ),
    bitrate="192k",
    sample_rate=44100,
)

saved_path = synthesize_speech(request)
print(f"Generated: {saved_path}")
```

### 7.4 Generating Mascot Animal Reward Audio
To regenerate the curated mascot audio clips (`assets/audio/animals/score_0_ant.mp3` through `score_10_bear.mp3`) with strict French pronunciation validation:
```bash
# Regenerate all 11 mascot sounds
python scripts/generate_short_animal_sounds.py

# Regenerate a specific score (e.g., bear score 10)
python scripts/generate_short_animal_sounds.py --score 10
```

### 7.5 Direct Flash 3.8 TTS REST API Specification
Under the hood, `src/tts_generator.py` communicates directly with Google Cloud Vertex AI:

* **Endpoint:**
  ```http
  POST https://aiplatform.googleapis.com/v1/projects/{PROJECT_ID}/locations/global/publishers/google/models/gemini-3.8-flash-tts:generateContent
  ```
* **Headers:**
  ```http
  Authorization: Bearer <GCP_OAUTH_ACCESS_TOKEN>
  Content-Type: application/json
  ```
* **JSON Request Body:**
  ```json
  {
    "contents": [
      {
        "role": "user",
        "parts": [
          {
            "text": "Où est la lettre A ?",
            "speechMetadata": {
              "style": "Voix en français. Voix féminine d'institutrice, chaleureuse et invitante."
            }
          }
        ]
      }
    ],
    "generationConfig": {
      "responseModalities": ["AUDIO"],
      "speechConfig": {
        "voiceConfig": {
          "prebuiltVoiceConfig": {
            "voiceName": "Aoede"
          }
        }
      }
    }
  }
  ```
* **Response Processing:**
  The API returns a JSON payload with Base64-encoded raw audio:
  ```json
  {
    "candidates": [
      {
        "content": {
          "parts": [
            {
              "inlineData": {
                "mimeType": "audio/x-wav",
                "data": "<BASE64_ENCODED_WAV_BYTES>"
              }
            }
          ]
        }
      }
    ]
  }
  ```
* **Encoding to MP3 via FFmpeg:**
  Base64 bytes are decoded to a temporary `.wav` file, then converted to 192 kbps MP3:
  ```bash
  ffmpeg -y -i temp.wav -ar 44100 -b:a 192k output.mp3
  ```

### 7.6 Voice Persona Reference
| Language | Role | Voice Name | Gender | Protobuf `prebuiltVoiceConfig` | Style Tone |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **French** | Female Voice | `Aoede` | `FEMALE` | `{"voiceName": "Aoede"}` | Institutrice, douce, bienveillante, invitante |
| **French** | Male Voice | `Puck` | `MALE` | `{"voiceName": "Puck"}` | Instituteur, doux, bienveillant, enthousiaste |
| **English** | Female Voice | `Kore` | `FEMALE` | `{"voiceName": "Kore"}` | Preschool teacher, warm, gentle, clear diction |
| **English** | Male Voice | `Fenrir` | `MALE` | `{"voiceName": "Fenrir"}` | Preschool teacher, energetic, supportive, clear |

### 7.7 Generating English Audio Batch
To generate all English voice clips (`assets/audio/en/voice_female/` and `assets/audio/en/voice_male/`):
```bash
python scripts/generate_all_audio_en.py
```
This script generates 26 letters + 20 numbers + 24 phonetics (excluding `X`) × 3 utterance types × 2 voices.


