from PIL import Image
import array

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
    for i in range(16):
        r = palette[p]
        g = palette[p + 1]
        b = palette[p + 2]

        d = ((color[0] - r) * 0.30) ** 2 + ((color[1] - g) * 0.59) ** 2 + ((color[2] - b) * 0.11) ** 2

        if d < cmin:
            cmin = d
            approx = i
        p += 3
    return approx


lastTile = 0

def convert2tile(palette, tiles, block):
    global lastTile
    halfSize = block.resize((2, 2))
    arr = halfSize.tobytes()

    # convert to vera default palette
    data = [0] * 4
    j = 0
    for i in range(0, len(arr), 3):
        color = (arr[i], arr[i+1], arr[i+2])
        index = findNearestColor(palette, color)
        data[j] = index
        j += 1

    data = tuple(data)

    # check if the block already exists
    if data not in tiles:
        # check if the new tile is not a vflip/hflip from another tile
        vflip = tuple([data[2], data[3], data[0], data[1]])
        hflip = tuple([data[1], data[0], data[3], data[2]])
        hvflip = tuple([data[3], data[2], data[1], data[0]])
        if vflip in tiles:
            tiles[data] = {
                'index': tiles[vflip]['index'],
                'vflip': True,
                'hflip': False
            }
        elif hflip in tiles:
            tiles[data] = {
                'index': tiles[hflip]['index'],
                'vflip': False,
                'hflip': True
            }
        elif hvflip in tiles:
            tiles[data] = {
                'index': tiles[hvflip]['index'],
                'vflip': True,
                'hflip': True
            }
        else:
            tiles[data] = {
                'index': lastTile,
                'vflip': False,
                'hflip': False
            }
            lastTile += 1

    return tiles[data]


def convertBackgound(file):
    palette = loadDefaultPalette()

    image = Image.open(file)
    if image.format != "PNG":
        print("only PNG supported")
        exit(-1)

    if image.mode == "P":
        """
        8 bits palette mode
        """
        image = image.convert("RGB")

    tiles = {}
    tilemap = [0] * int(image.width * image.height / (8 * 8)) * 2
    p = 0
    # slice the image in 16x16 tiles
    for y in range(0, image.height, 8):
        for x in range(0, image.width, 8):
            block = image.crop((x, y, x + 8, y + 8))
            tile = convert2tile(palette, tiles, block)
            tilemap[p] = str(tile["index"] + 10)
            tilemap[p + 1] = str((tile["vflip"] << 3) | (tile["hflip"] << 2))
            p += 2

    # cross build tileset
    # find the nearest used color from the palette
    reverseTiles = {}
    for d in tiles:
        reverseTiles[tiles[d]["index"]] = d

    # save
    f = open("tilemap.inc", 'a')

    for i in range(len(reverseTiles)):
        f.write("tile%sbg:\n" % i)
        tile = reverseTiles[i]
        for y in range(16):
            d = []
            for x in range(16):
                p = int(x / 8) + int(y/8)*2
                d.append(str(tile[p]))
            f.write("\t.byte %s\n" % (",".join(d)))

    f.write("tilebgend:\n")

    f.write("bgmapdata:\n")
    f.write("\t.byte %s\n" % (",".join(tilemap)))

    f.close()

if __name__ == "__main__":
    convertBackgound("background.png")
