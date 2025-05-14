# Phase 0.3 Scope – Color Extraction & Baseline Season Assignment  *(with Quick Wins)*

## 1. Objective
Deliver the first **user‑visible insight**: capture face & hair color in real time, classify into the 4 macro‑seasons (Spring, Summer, Autumn, Winter), and persist the result. This is the foundation for 12‑season precision in later phases.

---

## 2. Success Criteria (Definition of Done)

| # | Acceptance Criterion | Measure/Test |
|---|----------------------|--------------|
| **AC‑1** | App extracts average skin‑tone and hair‑tone values (RGB **and** CIELAB) every frame | Debug overlay shows live numeric values within ±3 ΔE of ground‑truth color swatches in calibration footage |
| **AC‑2** | On user command **"Analyze"**, app classifies into Spring / Summer / Autumn / Winter within 5 s | Result view displays season badge; unit test feeds canned frames and asserts correct label |
| **AC‑3** | Preview runs at ≥20 FPS on iPhone 12 and newer | Xcode Instruments trace shows mean >20 FPS with ≤70 % CPU |
| **AC‑4** | Users can **Save** a result and reopen it from "My Season" | QA script: analyze → save → force‑quit → reopen → result persists |
| **AC‑5** | Graceful handling of error states (no face, poor light, multiple faces) | Trigger each condition → confirm correct guidance toast |

---

## 3. Core Features In Scope

| Workstream | Feature / Deliverable | Notes |
|------------|----------------------|-------|
| **A. Data Pipeline** | • Skin & hair mask isolation using Image Segmenter output<br>• Sampling strategy (median of largest connected component) → RGB → Lab conversion (`simd_float3x3` on GPU) | Segmentation mask down‑scaled to 256 × 256 |
| **B. Baseline Classifier** | • Rule‑based hue/value/chroma thresholds → 4 macro‑seasons<br>• Config file `thresholds.json` for tuning | Log ΔE to adjacent season for analytics |
| **C. Result UI** | • `AnalysisResultView` (SwiftUI)<br>• Season badge + short description + Save button<br>• "Retry" & "See Details" (stub) actions | Follows MVVM; ViewModel publishes `AnalysisResult` |
| **D. Persistence** | • `AnalysisResult` entity in Core Data<br>• `SavedResultsView` list | Core Data chosen for future iCloud sync |
| **E. Diagnostics & QA** | • Hidden 3‑finger‑tap debug overlay showing FPS, Lab values, ΔE margins | Accelerates threshold tuning & testing |
| **F. Non‑Functional** | • Performance optimisation (Metal buffer reuse, classifier throttled to 10 Hz)<br>• Unit & integration tests | Target iOS 13+ |

---

## 4. Quick Wins Adopted Immediately

| Quick‑Win | Effort | Benefit |
|-----------|--------|---------|
| **Frame‑quality scoring** (centered face, exposure range) gates "Analyze" button | ~½ day | Cuts mis‑captures & false results |
| **Async segmentation throttle** – process **every 2nd frame** | Negligible (1‑line guard) | +8–10 FPS on A14 devices without degrading color stability |
| **ΔE proximity logging** – overlay logs margin to next‑closest season | Already part‑of debug overlay | Provides data for later threshold tuning & screenshot‑pipeline evaluation |

---

## 5. Out of Scope (for this phase)

* 12‑season fine‑grain classification  
* Personalized season pages & styling recommendations  
* Backend accounts / cloud storage  
* In‑app educational overhaul  
* Full UI theming per season (keep neutral)

---

## 6. Milestones & Effort (2‑Sprint Estimate)

| Week | Milestone | Owner |
|------|-----------|-------|
| **W1** | Implement Lab conversion utility & integrate into MediaPipe callback | iOS Eng |
| **W1** | Implement rule‑based classifier + unit tests | iOS Eng |
| **W1** | Implement **Frame‑quality scoring** quick‑win | iOS Eng |
| **W1‑2** | Build `AnalysisResultView` + Save flow | iOS Eng / UX |
| **W2** | Core Data stack & `SavedResultsView` | iOS Eng |
| **W2** | Implement **Segmentation throttle** + **ΔE logging** quick‑wins | iOS Eng |
| **W2** | Performance tuning, error‑state UX copy, QA pass | iOS Eng / QA / PM |

---

## 7. Key Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Segmentation accuracy varies with lighting → wrong averages | Misclassification & user distrust | Use frame‑quality score; block analyze under poor light |
| Older devices dip <20 FPS | Poor UX | Throttle segmentation (quick‑win); drop overlay resolution dynamically |
| Thresholds too coarse | Negative reviews | ΔE logging quick‑win provides tuning data; schedule threshold‑tuning sprint |

---

## 8. Dependencies

* **MediaPipe** multi‑class model already bundled  
* Existing prototype camera/overlay pipeline  
* Badge design assets  
* Calibration videos for each macro‑season

---

## 9. Go / No‑Go Checklist for Production Build 0.3

1. ✅ All AC‑1…AC‑5 met on iPhone 12, 13 mini, 14 Pro  
3. ✅ Average analysis time ≤5 s  
4. ✅ Performance metrics logged (FPS, CPU, ΔE margins)  
5. ✅ Design & Engineering sign‑off on UI copy 

---

## 10. Next Enhancement After This Phase

Begin R&D on **Landmark + Strategic‑Screenshot Pipeline** for 12‑season precision and richer personalization while collecting performance & accuracy data via feature flag.

---

## 11. Implementation Checklist

### Week 1: Foundation & Core Logic
- [x] **A. Data Pipeline**
  - [x] Set up Image Segmenter integration for face and hair masks
  - [x] Implement downscaling to 256×256 for segmentation masks
  - [x] Create median sampling algorithm for largest connected component
  - [x] Implement RGB → Lab color conversion using GPU acceleration
  - [x] Unit test color conversion accuracy against reference values
  
- [x] **B. Classifier**
  - [x] Design `thresholds.json` schema for season classification
  - [x] Implement rule-based classifier with configurable thresholds
  - [x] Add unit tests with reference color samples for each season
  - [x] Add ΔE distance logging to adjacent seasons

- [x] **C. Quick Wins (Part 1)**
  - [x] Implement frame quality scoring (face centering, exposure)
  - [ ] Add UI indicators for frame quality
  - [ ] Gate "Analyze" button based on quality scores

- [ ] **D. Result UI (Start)**
  - [ ] Create `AnalysisResult` model & view model
  - [ ] Design basic `AnalysisResultView` layout
  - [ ] Import season badge assets

### Week 2: UI Polish & Performance
- [ ] **E. Result UI (Complete)**
  - [ ] Finalize `AnalysisResultView` with animations
  - [ ] Implement "Retry" functionality
  - [ ] Add "See Details" stub for future expansion
  - [ ] Implement Save button
  
- [ ] **F. Persistence**
  - [ ] Set up Core Data model with `AnalysisResult` entity
  - [ ] Implement save/load functionality
  - [ ] Create `SavedResultsView` list UI
  - [ ] Add data migration path for future updates

- [ ] **G. Quick Wins (Part 2)**
  - [x] Implement async segmentation throttle (every 2nd frame)
  - [ ] Add ΔE proximity logging to debug overlay
  - [ ] Create hidden 3-finger-tap debug overlay

- [ ] **H. Performance & Polish**
  - [x] Optimize Metal buffer reuse
  - [ ] Throttle classifier to 10Hz
  - [ ] Add error state guidance for all edge cases
  - [ ] Conduct performance testing on target devices
  - [ ] Document final thresholds and performance metrics

### Final Validation
- [ ] **I. QA & Release Readiness**
  - [ ] Verify all AC-1 through AC-5 success criteria
  - [ ] Complete Go/No-Go checklist items
  - [ ] Conduct user acceptance testing
  - [ ] Prepare release notes
  - [ ] Finalize documentation for next phase planning

---

*Prepared for: **John Murphy (Product Manager)** – *May 13 2025*
