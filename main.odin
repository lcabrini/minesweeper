package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

WIDTH :: 1024
HEIGHT :: 768
TITLE :: "Minewsweeper"

MARGIN :: 32
CELL_SIZE :: 32
GRID_WIDTH :: 16
GRID_HEIGHT :: 16
MINE_COUNT :: 32
COUNTER_SIZE :: 20

Flag :: enum {
    NONE,
    FLAG,
    MAYBE,
}

Cell :: struct {
    x: i32,
    y: i32,
    has_mine: bool,
    flag: Flag,
    opened: bool,
    adjacent_mines: i32,
}

main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(WIDTH, HEIGHT, TITLE)
    rl.SetTargetFPS(60)

    counter_colors: []rl.Color = {
        rl.BLANK,
        rl.RAYWHITE,
        rl.YELLOW,
        rl.ORANGE,
        rl.BLUE,
        rl.GREEN,
        rl.PURPLE,
        rl.RED,
        rl.BROWN,
    }

    grid: [dynamic]Cell
    init_grid(&grid, GRID_WIDTH, GRID_HEIGHT)
    place_mines(&grid, GRID_WIDTH, GRID_HEIGHT, MINE_COUNT)
    count_adjacent_mines(&grid)

    for !rl.WindowShouldClose() {
        if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
            cell := get_mouse_cell(&grid)
            if cell.x >= 0 && cell.x < 16 && cell.y >= 0 && cell.y < 16 {
                fmt.println(cell)
                if cell.has_mine {
                    fmt.println("BOOM!")
                } else if cell.adjacent_mines > 0 {

                    cell.opened = true

                }
            }
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        draw_grid(16, 16)

        for cell in grid {
            if cell.has_mine {
                x := cell.x * CELL_SIZE + MARGIN + 1
                y := cell.y * CELL_SIZE + MARGIN + 1
                w: i32 = CELL_SIZE - 2
                h: i32 = CELL_SIZE - 2
                rl.DrawRectangle(x, y, h, w, rl.GRAY)
            } else if cell.opened {
                s := strings.clone_to_cstring(fmt.tprint(cell.adjacent_mines))
                tw := rl.MeasureText(s, COUNTER_SIZE)
                x := MARGIN + cell.x * CELL_SIZE + (CELL_SIZE / 2 - tw / 2)
                y := MARGIN + cell.y * CELL_SIZE + (CELL_SIZE / 2 - COUNTER_SIZE / 2)
                rl.DrawText(s, x, y, COUNTER_SIZE, counter_colors[cell.adjacent_mines])
            }
        }
        rl.EndDrawing()
    }
}

init_grid :: proc(grid: ^[dynamic]Cell, w, h: i32) {
    for r in 0..<w {
        for c in 0..<h {
            cell := Cell{}
            cell.x = c
            cell.y = r
            append(grid, cell)
        }
    }
}

draw_grid :: proc(w, h: i32) {
    for r: i32 = 0; r <= h; r += 1 {
        rl.DrawLine(MARGIN, r*CELL_SIZE+MARGIN, h*CELL_SIZE+MARGIN, r*CELL_SIZE+MARGIN, rl.RAYWHITE)
    }

    for c: i32 = 0; c <= w; c += 1 {
        rl.DrawLine(c*CELL_SIZE+MARGIN, MARGIN, c*CELL_SIZE+MARGIN, w*CELL_SIZE+MARGIN, rl.RAYWHITE)
    }
}

get_mouse_cell :: proc(grid: ^[dynamic]Cell) -> ^Cell {
    mp := rl.GetMousePosition()
    x := mp.x >= MARGIN ? i32(mp.x / CELL_SIZE - 1) : -1
    y := mp.y >= MARGIN ? i32(mp.y / CELL_SIZE - 1) : -1

    for &cell in grid {
        if x == cell.x && y == cell.y {
            return &cell
        }
    }

    return nil
}

place_mines :: proc(grid: ^[dynamic]Cell, w, h: i32, count: int) {
    placed := 0
    outer: for {
        x := rl.GetRandomValue(0, w-1)
        y := rl.GetRandomValue(0, h-1)

        for &cell in grid {
            if cell.x == x && cell.y == y {
                if cell.has_mine do continue outer

                cell.has_mine = true
                placed += 1
                break
            }
        }

        if placed >= count do return
    }
}

count_adjacent_mines :: proc(grid: ^[dynamic]Cell) {
    for i := 0; i < len(grid); i += 1 {
        cell := &grid[i]
        if !cell.has_mine {
            count: i32 = 0
            if cell.y - 1 >= 0 {
                if cell.x - 1 >= 0 && grid[i-GRID_WIDTH-1].has_mine do count += 1
                if grid[i-GRID_WIDTH].has_mine do count += 1
                if cell.x + 1 < GRID_WIDTH && grid[i-GRID_WIDTH+1].has_mine do count += 1
            }

            if cell.x - 1 >= 0 && grid[i-1].has_mine do count += 1
            if cell.x + 1 < GRID_WIDTH && grid[i+1].has_mine do count += 1

            if cell.y + 1 < GRID_HEIGHT {
                if cell.x - 1 >= 0 && grid[i+GRID_WIDTH-1].has_mine do count += 1
                if grid[i+GRID_WIDTH].has_mine do count += 1
                if cell.x + 1 < GRID_WIDTH && grid[i+GRID_WIDTH+1].has_mine do count += 1
            }

            cell.adjacent_mines = count
        }
    }
}
