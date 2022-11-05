from PIL import Image
from xml.dom import minidom


def loadDefaultPalette():
    """

    :return:
    """
    palette = Image.open("ColorPalette256x1.png")
    arr = palette.tobytes()
    return arr


def findNearestColor(palette, color):
    cmin = 99999
    p = 0
    approx = -1
    for i in range(256):
        r = palette[p]
        g = palette[p + 1]
        b = palette[p + 2]

        d = ((color[0] - r) * 0.30) ** 2 + ((color[1] - g) * 0.59) ** 2 + ((color[2] - b) * 0.11) ** 2

        if d < cmin:
            cmin = d
            approx = i
        p += 3
    return approx


def converLevel(source, target):
    """

    :param source:
    :param target:
    :return:
    """

    palette = loadDefaultPalette()

    dom = minidom.parse('level.tmx')
    map = dom.getElementsByTagName('map')
    tileheight = int(map[0].attributes['tileheight'].value)
    tilewidth = int(map[0].attributes['tilewidth'].value)

    tileset = dom.getElementsByTagName('tileset')
    tileset_file = tileset[0].attributes["source"].value

    layer = dom.getElementsByTagName('layer')[0]
    layerwidth = int(map[0].attributes['width'].value)
    layerheight = int(map[0].attributes['height'].value)

    xbackground = minidom.parse('background.tmx')
    xbgdata = xbackground.getElementsByTagName('data')
    sbgdata = xbgdata[0].childNodes[0].data
    sbgdata = sbgdata.replace("\n", "")
    bgdata = sbgdata.split(",")
    bgDataAttr = [0] * len(bgdata)

    for tile in range(len(bgdata)):
        gid = int(bgdata[tile])

        # extract tile flipping in TILED format
        hflip = gid & 0b10000000000000000000000000000000
        vflip = gid & 0b01000000000000000000000000000000
        gid =   gid & 0b00111111111111111111111111111111
        bgdata[tile] = gid

        # vflip & hflip are inverted on vera
        vflip = 4 if vflip else 0
        hflip = 8 if hflip else 0
        attr = hflip | vflip
        bgDataAttr[tile] = attr

    # extract data to array of int
    xdata = dom.getElementsByTagName('data')
    sdata = xdata[0].childNodes[0].data
    sdata = sdata.replace("\n", "")
    data = sdata.split(",")
    dataAttr = [0] * len(data)
    for tile in range(len(data)):
        gid = int(data[tile])

        # extract tile flipping in TILED format
        hflip = gid & 0b10000000000000000000000000000000
        vflip = gid & 0b01000000000000000000000000000000
        gid =   gid & 0b00111111111111111111111111111111
        data[tile] = gid

        # vflip & hflip are inverted on vera
        vflip = 4 if vflip else 0
        hflip = 8 if hflip else 0
        attr = hflip | vflip
        dataAttr[tile] = attr

    # find used tiles in the maps
    tilesref = {}
    for tile in data:
        tilesref[tile] = 1

    for tile in bgdata:
        tilesref[tile] = 1

    # convert tileID from global tileset to a tileID of an optimize tileset
    nbtiles = 0
    for t in sorted(list(tilesref.keys())):
        tilesref[t] = nbtiles
        nbtiles += 1

    # update the tilemap with the optimized ID
    # sdata = []
    binary = bytearray(len(data)*2 + 2)
    p = 2
    for i in range(len(data)):
        data[i] = tilesref[data[i]]
        # sdata.append(str(data[i]))              # tile index
        # sdata.append(str(dataAttr[i]))           # tile attribute
        binary[p] = data[i]          # tile index
        binary[p+1] = dataAttr[i]      # tile attribute
        p += 2

    # count for kernel issue with LOAD alsways missing the last 2 bytes
    binary[0] = (len(data)*2) & 0xff          # tile index
    binary[1] = (len(data)*2) >> 8      # tile attribute

    with open("bin/level.bin", "wb") as binary_file:
        binary_file.write(binary)

    # sbgdata = []
    p = 2
    for i in range(len(bgdata)):
        bgdata[i] = tilesref[bgdata[i]]
        # sbgdata.append(str(bgdata[i]))          # tile index
        # sbgdata.append(str(bgDataAttr[i]))      # tile attribute

        binary[p] = bgdata[i]          # tile index
        binary[p+1] = bgDataAttr[i]      # tile attribute
        p += 2

    # count for kernel issue with LOAD alsways missing the last 2 bytes
    binary[0] = (len(bgdata)*2) & 0xff          # tile index
    binary[1] = (len(bgdata)*2) >> 8      # tile attribute

    with open("bin/scenery.bin", "wb") as binary_file:
        binary_file.write(binary)

    # save
    f = open("tilemap.inc", 'w')

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

    # load the tileset
    tiledom = minidom.parse(tileset_file)
    ximage = tiledom.getElementsByTagName('image')
    image_file = ximage[0].attributes["source"].value
    image_width = ximage[0].attributes["width"].value
    image_height = ximage[0].attributes["height"].value

    # save the optimized tileset

    image = Image.open(image_file)
    if image.format != "PNG":
        print("only PNG supported")
        exit(-1)

    f.write("tileset:\n")
    f.write("\t.byte %d,%d\n" % (tilewidth, tileheight))

    if image.mode == "P":
        """
        8 bits palette mode
        f.write("palette:\n")
        f.write("\t.byte %s\n" % str(len(image.palette.colors)))
        d = []
        for c in image.palette.colors:
            d.append(str(c[0]))
            d.append(str(c[1]))
            d.append(str(c[2]))
        f.write("\t.byte %s\n" % (",".join(d)))
        """

        # find the nearest used color from the palette
        colorConversion = {}
        reverseColors = {}
        for c in image.palette.colors:
            reverseColors[image.palette.colors[c]] = c

        for i in range(len(reverseColors)):
            approx = findNearestColor(palette, reverseColors[i])
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
        # for y in range(tileheight):
        #     f.write("\t.byte %s\n" % (",".join(d)))
        # f.write("tile0end:;to computer size of one tile\n")

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

            # f.write("tile%s:\n" % tile)
            for y in range(tileheight):
                d = []
                for x in range(tilewidth):
                    colorIndex = arr[p]     # color 0 is always transparent, so shift the color index in the palette
                    colorIndex = colorConversion[colorIndex]    # nearest color in the default palette
                    d.append(str(colorIndex))
                    binary.append(colorIndex)
                    p += 1
                p += (image.width - tilewidth)
                # f.write("\t.byte %s\n" % (",".join(d)))

        # f.write("tileend:;to computer the number of tiles\n")

        binary[0] = (len(binary) - 2) & 0xff
        binary[1] = (len(binary) - 2) >> 8
        with open("bin/tiles.bin", "wb") as binary_file:
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
"""
converLevel("level.tmx", "tilemap.inc")