# Hero background image

Save the steampunk-octopus hero image here as:

```
interns/assets/hero-bg.jpg
```

The page references it from CSS: `.hero-img { background: url('assets/hero-bg.jpg') ... }`.

- Format: JPG or PNG (if PNG, rename the CSS reference in `index.html` accordingly).
- Recommended size: ~1920×1080 (the image is object-fit: cover, so it scales).
- If the file is missing, the hero falls back to a red/black gradient — the page still works, it just won't show the artwork.

The image is intentionally **not committed** in the first pass because it was shared via chat.
Drop the file in this folder and it will appear immediately (static hosting picks it up).
