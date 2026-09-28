# Synthetic EXIF fixtures

Eight tiny JPEGs generated from four colored quadrants encode the same upright
target using EXIF orientations 1–8, including mirrored variants. No personal image
or camera data is present. Flutter codec tests verify upright dimensions/pixels;
Archive tests preserve the encoded bytes independently of any rendered UI.
No production image-generation or recompression package was added.
