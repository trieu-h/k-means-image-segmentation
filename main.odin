package program

import "core:math"
import "core:math/rand"
import "core:time"
import rl "vendor:raylib"

dist_sqr :: proc(c1: rl.Color, c2: rl.Color) -> f32 {
	dr := f32(c2.r) - f32(c1.r)
	dg := f32(c2.g) - f32(c1.g)
	db := f32(c2.b) - f32(c1.b)
	return dr * dr + dg * dg + db * db
}

segment_photo :: proc(img: rl.Image) -> []rl.Color {
	original_pixels := rl.LoadImageColors(img)
	defer rl.UnloadImageColors(original_pixels)
	pixels := make([]rl.Color, size)

	for i in 0 ..< size {
		pixels[i] = original_pixels[i]
	}
	seed := time.time_to_unix(time.now())
	rand.reset(u64(seed))

	K :: 5
	centroids := [K]rl.Color{}
	for i in 0 ..< K {
		centroids[i] = pixels[rand.int31_max(size)]
	}

	for loop in 0 ..< 10 {
		count := [K]i32{}
		r_sum := [K]i32{}
		g_sum := [K]i32{}
		b_sum := [K]i32{}

		for i in 0 ..< size {
			smallest_dist: f32 = math.F32_MAX
			selected_centroid: int = 0

			for centroid, index in centroids {
				if dist := dist_sqr(original_pixels[i], centroid); dist < smallest_dist {
					smallest_dist = dist
					selected_centroid = index
				}
			}

			count[selected_centroid] += 1
			r_sum[selected_centroid] += i32(original_pixels[i].r)
			g_sum[selected_centroid] += i32(original_pixels[i].g)
			b_sum[selected_centroid] += i32(original_pixels[i].b)
			pixels[i] = centroids[selected_centroid]
		}

		for &centroid, i in centroids {
			if count[i] != 0 {
				centroid = rl.Color {
					u8(r_sum[i] / count[i]),
					u8(g_sum[i] / count[i]),
					u8(b_sum[i] / count[i]),
					255,
				}
			}
		}
	}

	return pixels
}

scale_image :: proc(img: ^rl.Image) {
	if (img.width <= MAX_WIDTH && img.height <= MAX_HEIGHT) {
		x = (MAX_WIDTH - img.width) / 2
		y = (MAX_HEIGHT - img.height) / 2
		size = img.width * img.height
	} else if (img.width > MAX_WIDTH && img.height <= MAX_HEIGHT) {
		ratio := f32(img.height) / f32(img.width)
		newHeight := i32(f32(MAX_WIDTH) * ratio)
		rl.ImageResize(img, MAX_WIDTH, newHeight)
		x = 0
		y = (MAX_HEIGHT - newHeight) / 2
		size = MAX_WIDTH * newHeight
	} else if (img.height > MAX_HEIGHT && img.width <= MAX_WIDTH) {
		ratio := f32(img.width) / f32(img.height)
		newWidth := i32(f32(MAX_HEIGHT) * ratio)
		rl.ImageResize(img, newWidth, MAX_HEIGHT)
		x = (MAX_WIDTH - newWidth) / 2
		y = 0
		size = MAX_HEIGHT * newWidth
	} else {
		scaleW := f32(MAX_WIDTH) / f32(img.width)
		scaleH := f32(MAX_HEIGHT) / f32(img.height)
		scale := min(scaleW, scaleH)
		newWidth := i32(f32(img.width) * scale)
		newHeight := i32(f32(img.height) * scale)
		rl.ImageResize(img, newWidth, newHeight)
		x = (MAX_WIDTH - newWidth) / 2
		y = (MAX_HEIGHT - newHeight) / 2
		size = newWidth * newHeight
	}
}

MAX_WIDTH: i32 = 1280
MAX_HEIGHT: i32 = 720
size := i32(MAX_WIDTH * MAX_HEIGHT)
img: rl.Image
texture: rl.Texture2D
imageLoaded := false
pixels: []rl.Color
last_index: i32 = 0
x: i32 = 0
y: i32 = 0

main :: proc() {
	rl.InitWindow(MAX_WIDTH, MAX_HEIGHT, "K-Means Image Segmentation")

	for !rl.WindowShouldClose() {
		if (rl.IsFileDropped()) {
			droppedFiles: rl.FilePathList = rl.LoadDroppedFiles()
			img = rl.LoadImage(droppedFiles.paths[0])
			rl.UnloadDroppedFiles(droppedFiles)
			scale_image(&img)
			texture = rl.LoadTextureFromImage(img)
			pixels = segment_photo(img)
			imageLoaded = true
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		if !imageLoaded {
			text: cstring = "Drag a photo here"
			FONT_SIZE := 36
			text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, f32(FONT_SIZE), 1)
			rl.DrawText(
				text,
				(MAX_WIDTH - i32(text_size.x)) / 2,
				(MAX_HEIGHT - i32(text_size.y)) / 2,
				i32(FONT_SIZE),
				rl.RAYWHITE,
			)
		} else {
			if last_index < size {
				for i in last_index ..< last_index + img.width {
					rl.ImageDrawPixel(&img, i % img.width, i / img.width, pixels[i])
				}
				rl.UpdateTexture(texture, img.data)
				rl.DrawTexture(texture, x, y, rl.WHITE)
				last_index += img.width
			} else {
				rl.DrawTexture(texture, x, y, rl.WHITE)
			}
		}

		rl.EndDrawing()
	}

	rl.UnloadTexture(texture)
	rl.UnloadImage(img)
	delete(pixels)
	rl.CloseWindow()
}
