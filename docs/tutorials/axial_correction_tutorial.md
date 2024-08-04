# Explained: Axial Offset Correction

## Background

Light beads traveling to our sample need to be temporally distinct relative to our sensor
so that the aquisition system knows the origin and subsequent depth of each bead.

The current LBM design incoorperates 2 cavities, hereby named `Cavity A` and `Cavity B`.
These two cavities are non-overlapping areas where light beads travel. If we plot
a sample pollen grain through each z-depth, we can see these cavities manifest:

```{thumbnail} ../_images/z_pollen_depth.svg
---
width: 600
align: center
---

```

We see a bi-modal distribution of Signal (Y) vs z-depth.

This pollen grain is sampled just like a brain would be sampled. We can
preview the time-series resulting from this pollen to get a preliminary
look at our recording quality:

```{thumbnail} ../_images/pollen/pollen_frame.png
---
width: 600
align: center
---

```

