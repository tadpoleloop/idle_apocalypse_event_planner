import re
from subprocess import Popen
STYLE_PATTERNS = ["\.ansi.*?\{.*?\}"]
FILE_NAME = 'best_solutions.html'
Popen(args = "jupyter nbconvert --no-input best_solutions.ipynb", shell = False).wait()
with open(FILE_NAME, 'r') as infile:
    input_html= infile.read()
output_html = "<style>\n"
for pattern in STYLE_PATTERNS:
    for match in re.finditer(pattern, input_html, re.DOTALL):
        output_html += match.group() + "\n"
output_html += "</style>\n"
output_html += "<body>\n"
match = re.search("\<pre\>.*\<\/pre\>", input_html, re.DOTALL)
output_html += match.group(0) + "\n"
output_html += "</body>"
with open(FILE_NAME, 'w') as outfile:
    outfile.write(output_html)