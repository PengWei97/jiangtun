# PRM1 – Multiphase-Field (MPF) Development Notes

## 1. Purpose

This module (`prm1_mpf_development`) is created to systematically develop and validate a multiphase-field (MPF) model based on Steinbach-type formulations.

The primary goal is to establish a **reliable numerical and physical foundation** for subsequent studies on:

- Triple junction dynamics
- Special grain boundary effects
- Anisotropic grain boundary energy and mobility
- Polycrystalline grain growth

---

## 2. Current Progress (p10_bicrystal)

The bicrystal benchmark (isotropic case) has been completed and validated.

### 2.1 Implementations

- Custom **Material class**
  - `TJ2PhaseMaterial`
- Custom **Kernel**
  - `TJ2PhaseACInterface`

- Single-order-parameter formulation:
  - φ₁ is solved explicitly
  - φ₂ = 1 − φ₁ (reconstructed)

- Bound-constrained formulation:
  - 0 ≤ φ₁ ≤ 1 enforced via VI solver (`vinewtonrsls`)

---

### 2.2 Benchmark Cases

#### (1) Flat Interface (Zero Curvature Test)

- File:
```

prm1_bi_iso_00_flat_interface_bounds_param.i

```

- Purpose:
- Verify **no artificial interface motion**
- Validate numerical stability under zero curvature

- Result:
- Interface remains stationary
- No drift observed
- Constraint and reconstruction stable

---

#### (2) Circular Grain Shrinkage

- File:
```

prm1_bi_iso_01_circle_shrink_bounds_param.i

```

- Purpose:
- Verify curvature-driven motion

- Results:
- Circular grain shrinks monotonically
- Interface remains smooth
- No numerical artifacts (no faceting, no locking)

---

### 2.3 Numerical Verification

#### (1) Mesh Convergence
- Multiple mesh resolutions tested
- Area–time curves converge
- Results consistent across grids

#### (2) Interface Width Sensitivity
- Different `int_width` tested
- Curves nearly overlap → weak thickness dependence

#### (3) mσ Scaling
- Increasing mσ → faster shrinkage
- Correct time scaling behavior

#### (4) Equivalent mσ Cross-Check
- Different (m, σ) pairs with same mσ
- Results overlap
- Confirms correct implementation of mobility-energy coupling

---

### 2.4 Auxiliary Quantities

- Grain boundary indicator:
```

bnds = φ₁² + φ₂²

```
- Bulk ≈ 1
- Interface < 1

---

## 3. Directory Structure (Current Scope)

```

p10_bicrystal/
├── isotropic/
│   ├── prm1_bi_iso_00_flat_interface_bounds_param.i
│   └── prm1_bi_iso_01_circle_shrink_bounds_param.i
├── scripts/
├── post/

```

---

## 4. Key Observations

- The current formulation is **numerically stable under bounds constraint**
- The system behaves as expected for:
  - Zero curvature
  - Curvature-driven shrinkage
- Time scale is correctly governed by mσ

---

## 5. Known Limitations / Open Issues

### (1) Double-Obstacle Approximation

- Current implementation uses:
  - PDE + bounds constraint
- This is **not a strict variational inequality formulation**
- The physical equivalence to the original Steinbach double-obstacle model still needs further investigation

---

### (2) Interface Thickness Effect

- Although weak in current tests, the role of `int_width` requires:
  - More systematic scaling analysis
  - Potential renormalization

---

### (3) Extension to Multi-Phase System

- Current model is reduced to bicrystal (two-phase)
- Multi-phase interaction terms are not yet included

---

## 6. Next Steps

### (1) Triple Junction (p20)

- Static equilibrium (120°)
- Unequal σ verification (Young’s law)
- Steady-state migration

### (2) Anisotropy

- Inclination-dependent σ
- Special grain boundary effects (e.g., Σ3)

### (3) Polycrystal (p30)

- Grain growth simulations
- Topological statistics

---

## 7. Remarks

The bicrystal benchmark serves as a **numerical and physical baseline** for all subsequent MPF developments.

All future implementations (triple junction, anisotropy, polycrystal) should be validated against this reference level.

---