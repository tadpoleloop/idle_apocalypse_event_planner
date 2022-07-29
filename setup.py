from distutils.core import setup
from Cython.Build import cythonize
setup(
    ext_modules=cythonize('./*.pyx', annotate = True), 
    script_args=['build_ext'],                                        
    options={'build_ext':{'inplace':True}}
)