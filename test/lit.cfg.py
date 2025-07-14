# lit.cfg.py

import os
import shutil
import lit.formats
# Global instance of LLVMConfig provided by lit
from lit.llvm import llvm_config

# name: The name of this test suite.
# (config is an instance of TestingConfig created when discovering tests)
config.name = 'CLANG-TUTOR'

# testFormat: The test format to use to interpret tests.
# As per shtest.py (my formatting):
#   ShTest is a format with one file per test. This is the primary format for
#   regression tests (...)
# I couldn't find any more documentation on this, but it seems to be exactly
# what we want here.
config.test_format = lit.formats.ShTest(not llvm_config.use_lit_shell)

# suffixes: A list of file extensions to treat as test files. This is overriden
# by individual lit.local.cfg files in the test subdirectories.
config.suffixes = ['.cpp']

# test_source_root: The root path where tests are located.
config.test_source_root = os.path.dirname(__file__)

# excludes: A list of directories to exclude from the testsuite. The 'Inputs'
# subdirectories contain auxiliary inputs for various tests in their parent
# directories.
config.excludes = ['Inputs']

# 测试执行文件的根目录 (通常是 CMake 构建目录下的 test 目录)
# lit 会自动推断这个，但如果需要可以显式设置
# config.test_exec_root = ...

# 测试使用的格式 (ShTest 是一个很好的默认值，它会执行 RUN: 行的 shell 命令)
config.test_format = lit.formats.ShTest(True)

# The list of tools required for testing
tools_to_find = [
    "FileCheck",
    "clang",
    "clang++"
]

# 去除了对于 CT_Clang_INSTALL_DIR=$Clang_DIR 的依赖
# 使用 shutil.which 来查找工具路径
for tool_name in tools_to_find:
    tool_path = shutil.which(tool_name)
    # 如果在 PATH 中找不到工具，则测试无法进行，立即报错并退出
    if tool_path is None:
        config.lit_config.fatal(
            f"Tool '{tool_name}' not found in PATH. "
            f"Please ensure it is available in your environment (e.g., via nix-shell)."
        )
    # 将工具路径添加到 substitutions 中
    substitution = f"%{tool_name}"
    config.substitutions.append((substitution, tool_path))

config.substitutions.append(('%shlibext', config.llvm_shlib_ext))
# The LIT variable to hold the location of plugins/libraries
config.substitutions.append(('%shlibdir', config.llvm_shlib_dir))
