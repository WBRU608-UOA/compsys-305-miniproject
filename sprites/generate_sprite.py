from PIL import Image

IMAGE = "./bird.png"

im = Image.open(IMAGE)
pixels = im.getdata()

width, height = im.size
romSize = width * height

print(f"{width * height} values.")

with open("sprites.mif", "w") as file:
    file.writelines([
        f"Depth = {romSize};\n",
        "Width = 12;\n",
        "Address_radix = hex;\n",
        "Data_radix = bin;\n",
        "Content\n",
        "Begin\n"
        ])
    
    
    for i, pixel in enumerate(pixels):
        if pixel[3] == 255:
            red = pixel[0] // 16
            green = pixel[1] // 16
            blue = pixel[2] // 16
            data = (red << 8) | (green << 4) | blue
            file.write(f"{hex(i)[2:]:>03} : {bin(data)[2:]:>012};\n")
        else:
            file.write(f"{hex(i)[2:]:>03} : 000000000000;\n")
    
    file.write("End;\n")