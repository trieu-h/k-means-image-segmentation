package program

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strings"
import "core:time"
import rl "vendor:raylib"

dist_sqr :: proc(c1: rl.Color, c2: rl.Color) -> f32 {
	dr := f32(c2.r) - f32(c1.r)
	dg := f32(c2.g) - f32(c1.g)
	db := f32(c2.b) - f32(c1.b)
	return dr * dr + dg * dg + db * db
}

segment_photo :: proc(img: rl.Image) -> []rl.Color {
	pixels := make([]rl.Color, size)

	for i in 0 ..< size {
		pixels[i] = original_pixels[i]
	}

	for loop in 0 ..< 10 {
		count := [colors_count]i32{}
		r_sum := [colors_count]i32{}
		g_sum := [colors_count]i32{}
		b_sum := [colors_count]i32{}

		for i in 0 ..< size {
			smallest_dist: f32 = math.F32_MAX
			selected_centroid: int = 0

			for centroid, index in colors {
				if dist := dist_sqr(original_pixels[i], centroid); dist < smallest_dist {
					smallest_dist = dist
					selected_centroid = index
				}
			}

			count[selected_centroid] += 1
			r_sum[selected_centroid] += i32(original_pixels[i].r)
			g_sum[selected_centroid] += i32(original_pixels[i].g)
			b_sum[selected_centroid] += i32(original_pixels[i].b)
			pixels[i] = colors[selected_centroid]
		}

		for &color, i in colors {
			if count[i] != 0 {
				color = rl.Color {
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
		resize_w = img.width
		resize_h = img.height
	} else if (img.width > MAX_WIDTH && img.height <= MAX_HEIGHT) {
		ratio := f32(img.height) / f32(img.width)
		newHeight := i32(f32(MAX_WIDTH) * ratio)
		rl.ImageResize(img, MAX_WIDTH, newHeight)
		x = 0
		y = (MAX_HEIGHT - newHeight) / 2
		size = MAX_WIDTH * newHeight
		resize_w = MAX_WIDTH
		resize_h = newHeight
	} else if (img.height > MAX_HEIGHT && img.width <= MAX_WIDTH) {
		ratio := f32(img.width) / f32(img.height)
		newWidth := i32(f32(MAX_HEIGHT) * ratio)
		rl.ImageResize(img, newWidth, MAX_HEIGHT)
		x = (MAX_WIDTH - newWidth) / 2
		y = 0
		size = MAX_HEIGHT * newWidth
		resize_w = newWidth
		resize_h = MAX_HEIGHT
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
		resize_w = newWidth
		resize_h = newHeight
	}
}

MAX_WIDTH: i32 = 1280
MAX_HEIGHT: i32 = 720
size := i32(MAX_WIDTH * MAX_HEIGHT)
resize_w: i32
resize_h: i32
img: rl.Image
texture: rl.Texture2D
image_loaded := false
original_pixels: [^]rl.Color
pixels: []rl.Color
last_index: i32 = 0
x: i32 = 0
y: i32 = 0
colors_selected := false
colors_count :: 5
colors: [colors_count]rl.Color
current_index := 0

OFFSET: i32 = 25
ZOOM_SIZE: i32 = 50
ZOOM_LEVEL: i32 = 5
zoom_texture: rl.Texture2D

main :: proc() {
	rl.InitWindow(MAX_WIDTH, MAX_HEIGHT, "K-Means Image Segmentation")

	for !rl.WindowShouldClose() {
		if (rl.IsFileDropped()) {
			droppedFiles: rl.FilePathList = rl.LoadDroppedFiles()
			defer rl.UnloadDroppedFiles(droppedFiles)
			img = rl.LoadImage(droppedFiles.paths[0])
			scale_image(&img)
			original_pixels = rl.LoadImageColors(img)
			texture = rl.LoadTextureFromImage(img)
			zoom_img := rl.GenImageColor(ZOOM_SIZE, ZOOM_SIZE, rl.WHITE)
			defer rl.UnloadImage(zoom_img)
			zoom_texture = rl.LoadTextureFromImage(zoom_img)
			image_loaded = true
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		if !image_loaded {
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
			if !colors_selected {
				INSTRUCTION_FONT_SIZE: i32 = 20
				rl.DrawTexture(texture, x, y, rl.WHITE)
				rl.DrawText(
					"PICK 5 COLORS FROM THE IMAGE",
					20,
					20,
					INSTRUCTION_FONT_SIZE,
					rl.RAYWHITE,
				)

				mouse_x := rl.GetMouseX()
				mouse_y := rl.GetMouseY()

				if (mouse_x >= x &&
					   mouse_x <= x + resize_w &&
					   mouse_y >= y &&
					   mouse_y <= y + resize_h) {
					zoom_area := rl.ImageFromImage(
						img,
						rl.Rectangle {
							f32(mouse_x - x - OFFSET),
							f32(mouse_y - y - OFFSET),
							f32(ZOOM_SIZE),
							f32(ZOOM_SIZE),
						},
					)
					defer rl.UnloadImage(zoom_area)
					rl.ImageResize(&zoom_area, ZOOM_SIZE * ZOOM_LEVEL, ZOOM_SIZE * ZOOM_LEVEL)

					cropped_portion_from_zoom_area := rl.ImageFromImage(
						zoom_area,
						rl.Rectangle {
							f32(ZOOM_SIZE * ZOOM_LEVEL / 2 - OFFSET),
							f32(ZOOM_SIZE * ZOOM_LEVEL / 2 - OFFSET),
							f32(ZOOM_SIZE),
							f32(ZOOM_SIZE),
						},
					)
					defer rl.UnloadImage(cropped_portion_from_zoom_area)

					rl.UpdateTexture(
						zoom_texture,
						rl.LoadImageColors(cropped_portion_from_zoom_area),
					)
					rl.DrawTexture(zoom_texture, mouse_x, mouse_y, rl.WHITE)

					ZOOM_RECT_SIZE: i32 = 10
					rl.DrawRectangleLines(
						rl.GetMouseX() + ZOOM_SIZE / 2 - ZOOM_RECT_SIZE / 2,
						rl.GetMouseY() + ZOOM_SIZE / 2 - ZOOM_RECT_SIZE / 2,
						ZOOM_RECT_SIZE,
						ZOOM_RECT_SIZE,
						rl.RED,
					)

					if (rl.IsMouseButtonPressed(rl.MouseButton.LEFT) &&
						   current_index <= colors_count + 1) {
						index := (mouse_y - y) * resize_w + (mouse_x - x)
						colors[current_index] = original_pixels[index]
						current_index += 1
					}
				}

				RIGHT_MENU_SIZE: i32 = 90
				RIGHT_MENU_FONT_SIZE: i32 = 16
				SPACE_BETWEEN_TEXT: i32 = 10

				text_y: i32 = 20
				for color in colors {
					if color != {0, 0, 0, 0} {
						color_str := fmt.tprintf("%d-%d-%d", color.r, color.g, color.b)
						rl.DrawText(
							strings.unsafe_string_to_cstring(color_str),
							MAX_WIDTH - 10 - RIGHT_MENU_SIZE,
							text_y,
							RIGHT_MENU_FONT_SIZE,
							color,
						)
					}
					text_y += RIGHT_MENU_FONT_SIZE + SPACE_BETWEEN_TEXT
				}

				if current_index == colors_count {
					colors_selected = true
					pixels = segment_photo(img)
				}
			} else {
				if last_index < size {
					for i in last_index ..< last_index + img.width {
						rl.ImageDrawPixel(&img, i % img.width, i / img.width, pixels[i])
					}
					rl.UpdateTexture(texture, img.data)
					rl.DrawTexture(texture, x, y, rl.RAYWHITE)
					last_index += img.width
				} else {
					rl.DrawTexture(texture, x, y, rl.RAYWHITE)
				}
			}
		}

		rl.EndDrawing()
	}

	rl.UnloadTexture(texture)
	rl.UnloadImage(img)
	rl.UnloadImageColors(original_pixels)
	delete(pixels)
	rl.CloseWindow()
}
