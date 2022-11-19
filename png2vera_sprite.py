from PIL import Image
from xml.dom import minidom


def load_default_palette():
    """

    :return:
    """
    palette = Image.open("ColorPalette256x1.png")
    arr = palette.tobytes()
    return arr


def find_nearest_color(palette, color):
    cmin = 99999
    p = 3
    approx = -1
    for i in range(1, 256):     # color 0 = transparent
        r = palette[p]
        g = palette[p + 1]
        b = palette[p + 2]

        d = ((color[0] - r) * 0.30) ** 2 + ((color[1] - g) * 0.59) ** 2 + ((color[2] - b) * 0.11) ** 2

        if d < cmin:
            cmin = d
            approx = i
        p += 3
    return approx


def convert_sprite(source, target):
    """

    :param source:
    :param target:
    :return:
    """
    palette = load_default_palette()

    # save the optimized tileset
    image = Image.open(source)
    if image.format != "PNG":
        print("only PNG supported")
        exit(-1)

    if image.mode == "P":
        """
        8 bits palette mode
        """
        # find the nearest used color from the palette
        color_conversion = {}
        reverse_colors = {}
        for c in image.palette.colors:
            reverse_colors[image.palette.colors[c]] = c

        for i in range(len(reverse_colors)):
            approx = find_nearest_color(palette, reverse_colors[i])
            color_conversion[i] = approx

        transparent_color = image.info["transparency"]

        # extract raw data
        arr = image.tobytes()

        f = open(target, 'w')
        f.write("fssprite:\t.literal \"%s\"\n" % "sprites.bin")
        f.write("fsspriteend:\n")
        f.write("sprites = %d\n" % int(len(arr) / (32 * 32)))
        f.write("sprite_size = %d\n" % int(32 * 32))

        sprite_id = 0
        binary = [0, 0]
        for sy in range(int(image.height / 32)):
            for sx in range(int(image.width / 32)):
                # f.write("sprite%d:\n" % sprite_id)
                sprite_id += 1

                # convert position to pixels
                px = sx * 32
                py = sy * image.width * 32
                p = py + px

                for y in range(32):
                    d = []
                    for x in range(32):
                        color_index = arr[p]  # color 0 is always transparent, so shift the color index in the palette
                        if color_index == transparent_color:
                            color_index = 0
                        else:
                            color_index = color_conversion[color_index]  # nearest color in the default palette
                        d.append(str(color_index))
                        binary.append(color_index)
                        p += 1
                    p += (image.width - 32)
                    # f.write("\t.byte %s\n" % (",".join(d)))

        # f.write("endsprite:\n")

        binary[0] = (len(binary) - 2) & 0xff
        binary[1] = (len(binary) - 2) >> 8

        with open("../bin/sprites.bin", "wb") as binary_file:
            b = bytearray(binary)
            binary_file.write(b)

    elif image.mode == "RGBA":
        """
        RGBA bits mode
        """
        arr = image.tobytes()
        print(arr)

    f.close()


"""
"""
convert_sprite("player.png", "../sprite.inc")