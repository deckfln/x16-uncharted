from PIL import Image
from xml.dom import minidom
import argparse


def array2binA(array, attribute, file):
    """

    :param file:
    :param attribute:
    :param array:
    :return:
    """
    binary = bytearray(len(array) * 2 + 2)
    p = 2
    for i in range(len(array)):
        binary[p] = array[i]          # tile index
        binary[p+1] = attribute[i]        # tile attribute
        p += 2

    # count for kernel issue with LOAD alsways missing the last 2 bytes
    binary[0] = (len(array)*2) & 0xff          # tile index
    binary[1] = (len(array)*2) >> 8      # tile attribute

    with open(file, "wb") as binary_file:
        binary_file.write(binary)


def array2bin(array, file):
    """

    :param file:
    :param array:
    :return:
    """
    binary = bytearray(len(array) + 2)
    p = 2
    for i in range(len(array)):
        binary[p] = array[i]          # tile index
        p += 1

    # count for kernel issue with LOAD alsways missing the last 2 bytes
    binary[0] = (len(array)*2) & 0xff          # tile index
    binary[1] = (len(array)*2) >> 8      # tile attribute

    with open(file, "wb") as binary_file:
        binary_file.write(binary)


def load_default_palette():
    """

    :return:
    """
    palette = Image.open(work_folder + "/ColorPalette256x1.png")
    arr = palette.tobytes()
    return arr


def find_nearest_color(color):
    cmin = 99999
    p = 0
    approx = -1
    for i in range(256):
        r = default_palette[p]
        g = default_palette[p + 1]
        b = default_palette[p + 2]

        d = ((color[0] - r) * 0.30) ** 2 + ((color[1] - g) * 0.59) ** 2 + ((color[2] - b) * 0.11) ** 2

        if d < cmin:
            cmin = d
            approx = i
        p += 3
    return approx


def load_tmx(file):
    """
    Load the content of a TMX level

    :param file:
    :return: dict of layers and data
    """
    tmx = {}
    dom = minidom.parse(file)
    map = dom.getElementsByTagName('map')

    tmx['tileheight'] = int(map[0].attributes['tileheight'].value)
    tmx['tilewidth'] = int(map[0].attributes['tilewidth'].value)

    # record the layers
    layers = {}
    xlayers = dom.getElementsByTagName('layer')
    id = 0
    for layer in xlayers:
        name = layer.attributes['name'].value

        layers[name] = {
            'id':  id,
            'width': int(layer.attributes['width'].value),
            'height': int(layer.attributes['height'].value),
            'data': layer.getElementsByTagName('data')[0].childNodes[0].data
        }
        id += 1
    tmx['layers'] = layers

    # record the tilesets
    tilesets = {}
    xtileset = dom.getElementsByTagName('tileset')
    for tileset in xtileset:
        source = tileset.attributes['source'].value
        tilesets[source] = int(tileset.attributes['firstgid'].value)
    tmx['tilesets'] = tilesets

    return tmx


def load_tsx(tsx_file):
    """

    :param tsx_file:
    :return: dict of the TSX
    """
    tsx = {}
    tiledom = minidom.parse(tsx_file)
    ximage = tiledom.getElementsByTagName('image')
    tsx["source"] = ximage[0].attributes["source"].value
    tsx["width"] = int(ximage[0].attributes["width"].value)
    tsx["height"] = int(ximage[0].attributes["height"].value)

    nb_tiles = 0

    xtiles = tiledom.getElementsByTagName('tile')
    tiles = {}
    for xtile in xtiles:
        xanimation = xtile.getElementsByTagName('animation')
        if xanimation:
            frames = {
                'id': nb_tiles,
                'frames': []
            }
            xframes = xanimation[0].getElementsByTagName('frame')
            for xframe in xframes:
                frame = {}
                frame["tileID"] = int(xframe.attributes["tileid"].value)
                frame["duration"] = int(xframe.attributes["duration"].value)

                frames['frames'].append(frame)

            id = int(xtile.attributes["id"].value)
            tiles[id] = frames
            nb_tiles = nb_tiles + 1

    tsx["tiles"] = tiles
    return tsx


def animation_tiles_optimize(tiles, tilesref):
    """

    :param tiles:
    :param tilesref:
    :return:
    """
    for tile in tiles.values():
        for frame in tile["frames"]:
            frame["tileID"] = tilesref[frame["tileID"]]


def animation_tiles_save(animations, tiles):
    """

    :param animations:
    :param tiles:
    :return:
    """
    data = []
    data.append(len(tiles))

    # pass 1, build the list of ANIMATED_TILE
    addr_tile = []

    for tile in tiles.values():
        addr_tile.append(len(data))

        data.append(0)                  # tick
        data.append(len(tile["frames"]))                  # nb_frames
        data.append(0)                  # current_frame
        data.append(0)                  # @frames
        data.append(0)
        data.append(len(animations[tile["id"]]))
        data.append(0)                  # @vera
        data.append(0)

    # pass 2, build the list of frames
    i = 0
    for tile in tiles.values():
        offset = len(data)
        data[addr_tile[i] + 3] = offset & 0xff   # register the start of the frames list at addr_frame offset (16 bits)
        data[addr_tile[i] + 4] = offset >> 8

        for frame in tile["frames"]:
            data.append(int(frame["duration"] / 16))
            data.append(frame["tileID"] + 1)        # convert to vera tiles, index 0 = transparent, so needs to add 1

        i += 1

    # pass 3, build the list of tiles offset in the tilemap
    for atile in animations.keys():
        offset = len(data)
        data[addr_tile[atile] + 6] = offset & 0x00ff  # register the start of the frames list at addr_frame offset (16 bits)
        data[addr_tile[atile] + 7] = offset >> 8

        for offset in animations[atile]:
            vera = offset * 2             # vera tile = tile index + tile attr
            data.append(vera & 0x00ff)    # offset in the tilemap / convert to 16 bits
            data.append(vera >> 8)

    bin = [0, 0]
    bin[0] = (len(data) - 2) & 0xff
    bin[1] = (len(data) - 2) >> 8
    bin.extend(data)

    with open(bin_folder + "/tilesani.bin", "wb") as binary_file:
        b = bytearray(bin)
        binary_file.write(b)


def save_image(source, sprite_height, sprite_width, bin_file, tilesref=None):
    """

    :param source:
    :param sprite_height:
    :param sprite_width:
    :param bin_file:
    :param tilesref:
    :return:
    """
    ##
    # load the tileset used by the main level
    #
    # save the optimized tileset

    image = Image.open(work_folder + "/" + source)
    if image.format != "PNG":
        print("only PNG supported")
        exit(-1)

    if image.mode == "P":
        """
        8 bits palette mode
        """

        # find the nearest used color from the palette
        colorConversion = {}
        reverseColors = {}
        for c in image.palette.colors:
            reverseColors[image.palette.colors[c]] = c

        for i in range(len(reverseColors)):
            approx = find_nearest_color(reverseColors[i])
            colorConversion[i] = approx

        # extract raw data
        arr = image.tobytes()

        # nb of tiles in the image
        tiles = int(image.width * image.height / (sprite_height * sprite_height))

        # dump tile0 = transparent tile
        nb_sprites_height = int(image.height / sprite_height)
        nb_sprites_width = int(image.width / sprite_width)

        binary = [0, 0]     # jsr LOAD needs the size of the file in the 2 first byte

        # dump the other tiles. Add1 because everything if slided by 1
        nb_tiles = 1
        for tile in range(tiles + 1):
            # ignore transparent tile
            if tile == 0:
                continue

            # only save sprites referenced in tilesref
            if tilesref and tile not in tilesref:
                continue

            nb_tiles += 1

            # position of the tile in the map
            # tile index - 1 as TMX uses tile #0 as transparent,
            # so tile #1 in TMx is actually tile #0 in the bitmap
            tx = int((tile - 1) % (image.width / nb_sprites_width))
            ty = int((tile - 1) / (image.width / nb_sprites_width))

            # convert position to pixels
            px = tx * nb_sprites_width
            py = ty * image.width * nb_sprites_width
            p = py + px

            for y in range(sprite_height):
                for x in range(sprite_width):
                    colorIndex = arr[p]     # color 0 is always transparent, so shift the color index in the palette
                    colorIndex = colorConversion[colorIndex]    # nearest color in the default palette
                    binary.append(colorIndex)
                    p += 1
                p += (image.width - sprite_width)

        binary[0] = (len(binary) - 2) & 0xff
        binary[1] = (len(binary) - 2) >> 8

        with open(bin_folder + "/" + bin_file, "wb") as binary_file:
            b = bytearray(binary)
            binary_file.write(b)

    elif image.mode == "RGBA":
        """
        RGBA bits mode
        """
        arr = image.tobytes()
        print(arr)


def convert_level(level_file, bg_file, target):
    """

    :param level_file:
    :param bg_file:
    :param target:
    :return:
    """

    level = load_tmx(work_folder + "/" + level_file)
    tsx = load_tsx(work_folder + "/" + "tileset16x16.tsx")

    tileheight = level['tileheight']
    tilewidth = level['tilewidth']
    layerwidth = level['layers']["level"]["width"]
    layerheight = level['layers']["level"]["height"]

    # list of tiles used in the tilemap
    tilesref = {0: 0}

    # extract the animated tiles
    tiles = tsx["tiles"]

    # store a list of animated tiles and their position on the tilemap
    animated_tiles = {}

    """
    tiles layer
    """
    sdata = level['layers']['level']['data'].replace("\n", "")
    data = sdata.split(",")
    dataAttr = [0] * len(data)
    for tile in range(len(data)):
        gid = int(data[tile])

        if gid == 0:
            data[tile] = gid
            continue

        # extract tile flipping in TILED format
        hflip = gid & 0b10000000000000000000000000000000
        vflip = gid & 0b01000000000000000000000000000000
        gid =   gid & 0b00111111111111111111111111111111
        data[tile] = gid

        # register the used tiles
        tilesref[gid] = 1

        # if this an animated tiles, register all animations
        lid = gid - 1
        if lid in tiles:
            for at in tiles.values():
                for frame in at["frames"]:
                    tilesref[frame["tileID"]] = 1
            aid = tiles[lid]['id']
            if aid not in animated_tiles:
                animated_tiles[aid] = [tile]
            else:
                animated_tiles[aid].append(tile)

        # vflip & hflip are inverted on vera
        if vflip:
            vflip = 8
        else:
            vflip = 0
        if hflip:
            hflip = 4
        else:
            hflip = 0

        attr = hflip | vflip
        dataAttr[tile] = attr

    """
    # collision layer
    """
    sCollisions = level['layers']['collisions']['data'].replace("\n", "")
    sCollisions = sCollisions.replace("\n", "")
    collisions = sCollisions.split(",")

    # loca tile index 0 => convert to 1 as 0 is no collision
    collision_tileset_gid = level['tilesets']['collisions.tsx'] - 1

    for tile in range(len(collisions)):
        gid = int(collisions[tile])

        # extract tile flipping in TILED format
        hflip = gid & 0b10000000000000000000000000000000
        vflip = gid & 0b01000000000000000000000000000000
        gid =   gid & 0b00111111111111111111111111111111

        if gid != 0:
            # convert from global tileset code to local code
            gid = gid - collision_tileset_gid

        if not 0 <= gid < 256:
            print("incorrect collision tile %s" % collisions[tile])
            exit(-1)

        collisions[tile] = gid

        # vflip & hflip are inverted on vera
        """
        vflip = 4 if vflip else 0
        hflip = 8 if hflip else 0
        attr = hflip | vflip
        dataAttr[tile] = attr
        """
    array2bin(collisions, bin_folder + "/collision.bin")

    """
    # sprite layer
    """
    sSprites = level['layers']['sprites']['data'].replace("\n", "")
    sSprites = sSprites.replace("\n", "")
    lSprites = sSprites.split(",")
    sprite_gid = level['tilesets']['sprites.tsx'] - 1
    y = 0
    x = 0
    sprites = [0, 0, 0]

    nb_sprites = 0
    sprite_ref = {}
    for tile in range(len(lSprites)):
        gid = int(lSprites[tile])
        if gid != 0:
            lx = x * 16
            ly = y * 16

            gid = gid - sprite_gid

            # entity class
            sprites.append(0)               # .BYTE EntityID
            sprites.append(0)               # .BYTE classID
            sprites.append(0)               # .BYTE spriteID
            sprites.append(0)               # .BYTE status
            sprites.append(0xff)            # .BYTE connectedID
            sprites.append(0)               # ?BYTE decimal lx
            sprites.append(lx & 0xff)       # .WORD lx
            sprites.append(lx >> 8)
            sprites.append(0)               # ?BYTE decimal ly
            sprites.append(ly & 0xff)       # .WORD ly
            sprites.append(ly >> 8)
            sprites.append(0)               # .BYTE falling ticks
            sprites.append(0)               # SIGNED WORD vtx
            sprites.append(0)               #
            sprites.append(0)               # WORD vty
            sprites.append(0)
            sprites.append(0)               # word gt
            sprites.append(0)
            sprites.append(16)              # BYTE bWidth
            sprites.append(16)              # BYTE bHeight
            sprites.append(0)               # BYTE bFeetIndex
            sprites.append(1+2+4)           # BYTE bFlags
            sprites.append(0)               # BYTE bXOffset
            sprites.append(0)               # BYTE bYOffset
            sprites.append(0)               # .WORD collision addr
            sprites.append(0)
            sprites.append(0)               # .WORD controler selection  call back (based on the current tile)
            sprites.append(0)
            # object class
            sprites.append(gid)             # .BYTE imageID
            sprites.append(1)               # .BYTE attribute = GRAB

            nb_sprites = nb_sprites + 1

            sprite_ref[gid] = True

        # move the cursor
        x = x + 1
        if x == level['layers']['sprites']['width']:
            x = 0
            y = y + 1

    sprites[0] = (len(sprites) - 2) & 0xff      # size of the block
    sprites[1] = (len(sprites) - 2) >> 8
    sprites[2] = nb_sprites                     # number of objects following

    with open(bin_folder + "/" + "objects.bin", "wb") as binary_file:
        b = bytearray(sprites)
        binary_file.write(b)

    tsx_sprites = load_tsx(work_folder + "/" + "sprites.tsx")
    sprite_file = tsx_sprites["source"]
    sprite_width = tsx_sprites["width"]
    sprite_height = tsx_sprites["height"]

    save_image(sprite_file, sprite_width, sprite_height, "sprites1.bin", sprite_ref)

    """
    background tileset
    """
    background = load_tmx(work_folder + "/" + bg_file)
    sbgdata = background["layers"]["level"]["data"].replace("\n", "")
    bgdata = sbgdata.split(",")
    bgDataAttr = [0] * len(bgdata)

    for tile in range(len(bgdata)):
        gid = int(bgdata[tile])

        # extract tile flipping in TILED format
        hflip = gid & 0b10000000000000000000000000000000
        vflip = gid & 0b01000000000000000000000000000000
        gid =   gid & 0b00111111111111111111111111111111
        bgdata[tile] = gid
        tilesref[gid] = 1

        # vflip & hflip are inverted on vera
        vflip = 4 if vflip else 0
        hflip = 8 if hflip else 0
        attr = hflip | vflip
        bgDataAttr[tile] = attr

    # convert tileID from global tileset to a tileID of an optimize tileset
    nbtiles = 0
    for t in sorted(list(tilesref.keys())):
        tilesref[t] = nbtiles
        nbtiles += 1

    # update the tilemap with the optimized ID
    for i in range(len(data)):
        data[i] = tilesref[data[i]]

    for i in range(len(bgdata)):
        bgdata[i] = tilesref[bgdata[i]]

    # update the animated tiles with the optimized ID
    animation_tiles_optimize(tiles, tilesref)

    # save everything
    array2binA(data, dataAttr, bin_folder + "/level.bin")
    array2binA(bgdata, bgDataAttr, bin_folder + "/scenery.bin")
    animation_tiles_save(animated_tiles, tiles)

    # save
    f = open(src_folder + "/" + target, 'w')

    # save the tilemap
    f.write("map:\n")
    f.write("\t.byte %d,%d\n" % (layerwidth, layerheight))
    # f.write("mapdata:\n")
    # f.write("\t.byte %s\n" % (",".join(sdata)))

    f.write("fslevel: .literal \"%s\"\n" % "level.bin")
    f.write("fslevel_end:\n")

    f.write("fsbackground: .literal \"%s\"\n" % "scenery.bin")
    f.write("fsbackground_end:\n")
    # f.write("\t.byte %s\n" % (",".join(sbgdata)))

    f.write("fscollision: .literal \"%s\"\n" % "collision.bin")
    f.write("fscollision_end:\n")

    f.write("fsobjects: .literal \"%s\"\n" % "objects.bin")
    f.write("fsobjects_end:\n")

    f.write("fssprites1: .literal \"%s\"\n" % "sprites1.bin")
    f.write("fssprites1_end:\n")

    ##
    # load the tileset used by the main level
    #
    image_file = tsx["source"]
    image_width = tsx["width"]
    image_height = tsx["height"]

    # save the optimized tileset

    image = Image.open(work_folder + "/" + image_file)
    if image.format != "PNG":
        print("only PNG supported")
        exit(-1)

    f.write("tileset:\n")
    f.write("\t.byte %d,%d\n" % (tilewidth, tileheight))

    if image.mode == "P":
        """
        8 bits palette mode
        """

        # find the nearest used color from the palette
        colorConversion = {}
        reverseColors = {}
        for c in image.palette.colors:
            reverseColors[image.palette.colors[c]] = c

        for i in range(len(reverseColors)):
            approx = find_nearest_color(reverseColors[i])
            colorConversion[i] = approx

        # extract raw data
        arr = image.tobytes()

        # nb of tiles in the image
        tiles = int(image.width * image.height / (tilewidth * tilewidth))

        # dump tile0 = transparent tile
        # f.write("tile0:\n")
        binary = [0, 0]
        for y in range(tileheight):
            for x in range(tilewidth):
                # d.append("0")
                binary.append(0)

        # dump the other tiles. Add1 because everything if slided by 1
        nb_tiles = 1
        for tile in range(tiles + 1):
            # ignore transparent tile
            if tile == 0:
                continue

            # only push used tiles in the tilemap's
            if tile not in tilesref:
                continue

            nb_tiles += 1

            # position of the tile in the map
            # tile index - 1 as TMX uses tile #0 as transparent,
            # so tile #1 in TMx is actually tile #0 in the bitmap
            tx = int((tile - 1) % (image.width / tilewidth))
            ty = int((tile - 1) / (image.width / tilewidth))

            # convert position to pixels
            px = tx * tilewidth
            py = ty * image.width * tilewidth
            p = py + px

            for y in range(tileheight):
                d = []
                for x in range(tilewidth):
                    colorIndex = arr[p]     # color 0 is always transparent, so shift the color index in the palette
                    colorIndex = colorConversion[colorIndex]    # nearest color in the default palette
                    d.append(str(colorIndex))
                    binary.append(colorIndex)
                    p += 1
                p += (image.width - tilewidth)

        binary[0] = (len(binary) - 2) & 0xff
        binary[1] = (len(binary) - 2) >> 8
        with open(bin_folder + "/tiles.bin", "wb") as binary_file:
            b = bytearray(binary)
            binary_file.write(b)

        f.write("tiles = %d\n" % nb_tiles)
        f.write("tile_size = %d\n" % (tilewidth * tileheight))
        f.write("fstile: .literal \"%s\"\n" % "tiles.bin")
        f.write("fstileend:\n")

    elif image.mode == "RGBA":
        """
        RGBA bits mode
        """
        arr = image.tobytes()
        print(arr)

    f.close()


"""
main programe
"""


parser = argparse.ArgumentParser(description='convert tmx file.')
parser.add_argument('-l ', help='tmx file')
parser.add_argument('-i', help='sum the integers (default: find the max)')

args = parser.parse_args()

work_folder = "./assets"
bin_folder = "./bin"
src_folder = "./src"
default_palette = load_default_palette()

convert_level("level.tmx", "background.tmx", "tilemap.inc")