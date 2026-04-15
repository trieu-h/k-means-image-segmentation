package program

import "core:fmt"
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

main :: proc() {
	img := rl.LoadImage("photo.jpg")
	defer rl.UnloadImage(img)

	rl.InitWindow(img.width, img.height, "K-Means Image Segmentation")
	texture := rl.LoadTextureFromImage(img)

	size := img.height * img.width
	original_pixels := rl.LoadImageColors(img)
	pixels := make([]rl.Color, size)
	defer rl.UnloadImageColors(original_pixels)
	defer delete(pixels)

	for i in 0 ..< size {
		pixels[i] = original_pixels[i]
	}

	seed := time.time_to_unix(time.now())
	rand.reset(u64(seed))

	K :: 3
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

	// for i in 0 ..< size {
	// 	rl.ImageDrawPixel(&img, i % img.width, i / img.width, pixels[i])
	// }
	//
	// rl.UpdateTexture(texture, img.data)

	last_index: i32 = 0
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		if last_index < size {
			for i in last_index ..< last_index + img.width {
				rl.ImageDrawPixel(&img, i % img.width, i / img.width, pixels[i])
			}
			rl.UpdateTexture(texture, img.data)
			rl.DrawTexture(texture, 0, 0, rl.WHITE)
		}
		rl.EndDrawing()
		last_index += img.width
	}

	rl.CloseWindow()
}
