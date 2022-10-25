const sf = @import("sfml.zig");
const std = @import("std");

const TileMap = @This();
const tile_util = @import("tile_util.zig");

const tilemap_dimension = 32;
const tile_count = tilemap_dimension * tilemap_dimension;

tiles: [tile_count]u8 = .{25} ** tile_count,
vertex_array: *sf.sfVertexArray,
offset_x: u32 = 250,
offset_y: u32 = 0,

// last_visible_tile_index_topleft: tile_util.Coord,
// last_visible_tile_index_botright: tile_util.Coord,

pub fn init() TileMap {
    const vertex_array = sf.sfVertexArray_create() orelse unreachable;
    sf.sfVertexArray_resize(vertex_array, tile_count * 4);
    sf.sfVertexArray_setPrimitiveType(vertex_array, sf.sfQuads);

    var tile_map = TileMap {
        .vertex_array = vertex_array
    };

    tile_map.initializeTiles();
    return tile_map;
}

pub fn deinit(self: *TileMap) void {
    sf.sfVertexArray_destroy(self.vertex_array);
}

pub fn draw(self: *TileMap, window: *sf.sfRenderWindow, tile_sheet: *sf.sfTexture) void {
    var identity_transform = sf.sfTransform { .matrix = .{ 1, 0, 0, 0, 1, 0, 0, 0, 1 } };
    
    self.offset_x += 1;
    self.offset_y += 2;
    sf.sfTransform_translate(&identity_transform, @intToFloat(f32, self.offset_x), @intToFloat(f32, self.offset_y));
    var render_state = sf.sfRenderStates {
        .blendMode = sf.sfBlendAlpha,
        .transform = identity_transform,
        .texture = tile_sheet,
        .shader = null
    };

    const window_view = sf.sfRenderWindow_getView(window) orelse unreachable;
    const view_size = sf.sfView_getSize(window_view);
    
    const OOB_offset_amount = tile_util.tile_pixel_dimension * 4; // we update tiles 4 steps outside our view

    const start_topleft = tile_util.FloatCoord {
        .x = -@intToFloat(f32, self.offset_x) - @intToFloat(f32, OOB_offset_amount),
        .y = -@intToFloat(f32, self.offset_y) - @intToFloat(f32, OOB_offset_amount)
    };
    const end_botright = tile_util.FloatCoord {
        .x = -@intToFloat(f32, self.offset_x) + view_size.x + @intToFloat(f32, OOB_offset_amount),
        .y = -@intToFloat(f32, self.offset_y) + view_size.y + @intToFloat(f32, OOB_offset_amount)
    };


    const start_x: i32 = @floatToInt(i32, @divFloor(start_topleft.x, tile_util.tile_pixel_dimension));
    const start_y: i32 = @floatToInt(i32, @divTrunc(start_topleft.y, tile_util.tile_pixel_dimension));

    const end_x = @floatToInt(i32, @divFloor(end_botright.x, tile_util.tile_pixel_dimension));
    const end_y = @floatToInt(i32, @divFloor(end_botright.y, tile_util.tile_pixel_dimension));
    var x = start_x;
    while (x < end_x) : (x += 1) {
        const wrapped_x = blk: {
            if (x < 0) {
                break :blk tilemap_dimension + @rem(x, tilemap_dimension) - 1;
            } else if (x >= tilemap_dimension) {
                break :blk @rem(x, tilemap_dimension) - tilemap_dimension;
            }
            break :blk @rem(x, tilemap_dimension);
        };

        var y = start_y;
        while (y < end_y) : (y += 1) {

            const wrapped_y = blk: {
                if (y < 0) {
                    break :blk tilemap_dimension + @rem(y, tilemap_dimension) - 1;
                } else if (y >= tilemap_dimension) {
                    break :blk @rem(y, tilemap_dimension) - tilemap_dimension;
                }

                break :blk @rem(y, tilemap_dimension);
            };

            self.setTilePosition(
                @intCast(usize, wrapped_x),
                @intCast(usize, wrapped_y),
                @intToFloat(f32, x * tile_util.tile_pixel_dimension),
                @intToFloat(f32, y * tile_util.tile_pixel_dimension));

        }
    }
    sf.sfRenderWindow_drawVertexArray(window, self.vertex_array, &render_state);
}


pub fn setTile(self: *TileMap, x: usize, y: usize, tile_index: u8) void {
    self.tiles[x + y * 32] = tile_index;
    self.refreshTileQuad(x, y, false);
}

fn setTilePosition(self: *TileMap, x: usize, y: usize, pos_x: f32, pos_y: f32) void {
    const quad_base_index = (x + y * 32) * 4;

    var vertex0 = sf.sfVertexArray_getVertex(self.vertex_array, quad_base_index + 0);
    var vertex1 = sf.sfVertexArray_getVertex(self.vertex_array, quad_base_index + 1);
    var vertex2 = sf.sfVertexArray_getVertex(self.vertex_array, quad_base_index + 2);
    var vertex3 = sf.sfVertexArray_getVertex(self.vertex_array, quad_base_index + 3);

    //var vertexX = sf.sfVertexArray_getVertex(self.vertex_array, (16 + 0 * 32) * 4 + 0);

    if (vertex0 == 0 or vertex1 == 0 or vertex2 == 0 or vertex3 == 0) {
        return;
    }

    vertex0.*.position = sf.sfVector2f { .x = pos_x, .y = pos_y };
    vertex1.*.position = sf.sfVector2f { .x = pos_x + tile_util.tile_pixel_dimension , .y = pos_y };
    vertex2.*.position = sf.sfVector2f { .x = pos_x + tile_util.tile_pixel_dimension, .y = pos_y + tile_util.tile_pixel_dimension };
    vertex3.*.position = sf.sfVector2f { .x = pos_x, .y = pos_y + tile_util.tile_pixel_dimension };
}

fn initializeTiles(self: *TileMap) void {
    var x: usize = 0;
    var y: usize = 0;
    while (x < 32) : (x += 1) {
        y = 0;
        while (y < 32) : (y += 1) {
            self.refreshTileQuad(x, y, true);
        }
    }
}

fn refreshTileQuad(self: *TileMap, x: usize, y: usize, update_position: bool) void {
    const quad_base_index = (x + y * 32) * 4;
    const tile_index = self.tiles[x + y * 32];

    var vertex0 = @ptrCast(?*sf.sfVertex, sf.sfVertexArray_getVertex(self.vertex_array, quad_base_index + 0)) orelse unreachable;
    var vertex1 = @ptrCast(?*sf.sfVertex, sf.sfVertexArray_getVertex(self.vertex_array, quad_base_index + 1)) orelse unreachable;
    var vertex2 = @ptrCast(?*sf.sfVertex, sf.sfVertexArray_getVertex(self.vertex_array, quad_base_index + 2)) orelse unreachable;
    var vertex3 = @ptrCast(?*sf.sfVertex, sf.sfVertexArray_getVertex(self.vertex_array, quad_base_index + 3)) orelse unreachable;

    // DEBUG TEST LINE: if (x == 16 and y % 5 == 0) (if (y == 30) 3 else tile_index) else 0);//TODO//
    const tile_coord = tile_util.getTileCoordinateFromTileIndex(tile_index);
    const tile_coord_pixel_x = @intToFloat(f32, tile_coord.x * tile_util.tile_pixel_dimension);
    const tile_coord_pixel_y = @intToFloat(f32, tile_coord.y * tile_util.tile_pixel_dimension);
    
    vertex0.color = sf.sfWhite;
    vertex1.color = sf.sfWhite;
    vertex2.color = sf.sfWhite;
    vertex3.color = sf.sfWhite;

    vertex0.texCoords = .{ .x = tile_coord_pixel_x, .y = tile_coord_pixel_y };
    vertex1.texCoords = .{ .x = tile_coord_pixel_x + tile_util.tile_pixel_dimension , .y = tile_coord_pixel_y };
    vertex2.texCoords = .{ .x = tile_coord_pixel_x + tile_util.tile_pixel_dimension, .y = tile_coord_pixel_y + tile_util.tile_pixel_dimension };
    vertex3.texCoords = .{ .x = tile_coord_pixel_x, .y = tile_coord_pixel_y + tile_util.tile_pixel_dimension };

    if (update_position) {
        const x_pos = @intToFloat(f32, x * tile_util.tile_pixel_dimension);
        const y_pos = @intToFloat(f32, y * tile_util.tile_pixel_dimension);

        vertex0.position = .{ .x = x_pos, .y = y_pos };
        vertex1.position = .{ .x = x_pos + tile_util.tile_pixel_dimension , .y = y_pos };
        vertex2.position = .{ .x = x_pos + tile_util.tile_pixel_dimension, .y = y_pos + tile_util.tile_pixel_dimension };
        vertex3.position = .{ .x = x_pos, .y = y_pos + tile_util.tile_pixel_dimension };
    }
}
