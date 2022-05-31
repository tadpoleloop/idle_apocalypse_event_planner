class Colors:
    BOLD = "\033[1m"
    BLUE = "\033[34;1m"
    GREEN = "\033[32;1m"
    RED = "\033[31;1m"
    GOLD = '\033[33;1m'
    PURPLE = "\033[35;1m"
    BLACK = '\033[30;1m'
    RESET = "\033[0m"
    
    @staticmethod
    def color(text, color):
        if color.lower() == 'blue':
            return Colors.BLUE + text + Colors.RESET
        elif color.lower() == 'green':
            return Colors.GREEN + text + Colors.RESET
        elif color.lower() == 'red':
            return Colors.RED + text + Colors.RESET
        elif color.lower() == 'gold':
            return Colors.GOLD + text + Colors.RESET
        elif color.lower() == 'bold':
            return Colors.BOLD + text + Colors.RESET
        elif color.lower() == 'purple':
            return Colors.PURPLE + text + Colors.RESET
        elif color.lower() == 'rainbow':
            return Colors.rainbow(text)
        else:
            raise NotImplementedError
            
    @staticmethod 
    def rgb(text, r, g, b):
        return f"\033[38;2;{r};{g};{b}m{str(text)}"
            
    @staticmethod
    def rainbow(text):
        HUE_RANGE = (0, 0.67)
        BRIGHTNESS = 0.75 #hard to see yellows if it is too bright
        n_chars = len(text) - text.count(" ")
        if n_chars == 1:
            return text
        i = 0
        rainbow_text = Colors.BOLD
        for c in text:
            if c == " ":
                rainbow_text += " "
                continue
            hue = HUE_RANGE[0] + i / (n_chars - 1) * (HUE_RANGE[1] - HUE_RANGE[0]) # walk the HUE_RANGE
            r,g,b = Colors.hsv_to_rgb(hue, 1, BRIGHTNESS)
            rainbow_text += Colors.rgb(c, r, g, b)
            i += 1
        return rainbow_text + Colors.RESET
    
    @staticmethod
    def hsv_to_rgb(hue, saturation, value):
        """
        hsv as a float from 0 - 1 and rgb as an integer from 0 to 255
        """
        assert 0 <= hue <= 1 and 0 <= saturation <= 1 and 0 <= value <= 1
        chroma = saturation * value
        x = abs((6 * hue) % 2 - 1) # number between 0 and 1 basically how bright(dim) the middle colour is
        #high medium and low values
        h, m, l = int(255 * value), int(255 * (value - chroma * x)), int(255 * (value - chroma))
        if (6 * hue) < 1:
            return h, m, l
        elif (6 * hue) < 2:
            return m, h, l
        elif (6 * hue) < 3:
            return l, h, m
        elif (6 * hue) < 4:
            return l, m, h
        elif (6 * hue) < 5:
            return m, l, h
        elif (6 * hue) <= 6:
            return h, l, m
        else:
            raise ValueError