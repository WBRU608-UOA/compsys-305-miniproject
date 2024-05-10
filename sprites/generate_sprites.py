from PIL import Image

IMAGES = [
    "./bird.png",
    "./red.png"
]


with open("sprites.mif", "w") as file:
    file.writelines([
        "Depth = 65536;\n",
        "Width = 12;\n",
        "Address_radix = hex;\n",
        "Data_radix = bin;\n",
        "Content\n",
        "Begin\n"
        ])
    
    romSize = 0
    for path in IMAGES:
        im = Image.open(path)
        pixels = im.getdata()

        width, height = im.size
        
        for i, pixel in enumerate(pixels):
            if len(pixel) == 3 or pixel[3] == 255:
                red = pixel[0] // 16
                green = pixel[1] // 16
                blue = pixel[2] // 16
                data = (red << 8) | (green << 4) | blue
                file.write(f"{hex(i + romSize)[2:]:>03} : {bin(data)[2:]:>012};\n")
            else:
                file.write(f"{hex(i + romSize)[2:]:>03} : 000000000000;\n")

        romSize += width * height   
    
    

    
    file.write("End;\n")
    
    print(f"{romSize} values.")