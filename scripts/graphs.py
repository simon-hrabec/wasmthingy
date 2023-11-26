import matplotlib.pyplot as plt
import numpy as np
from numpy import genfromtxt
from matplotlib.backends.backend_pdf import PdfPages
import sys

data_dir = sys.argv[1]
output_pdf = sys.argv[2]

pdf = PdfPages(output_pdf)

data_no_prio = genfromtxt(data_dir+'/data_no_prio', delimiter=';')
data_with_prio_cpp = genfromtxt(data_dir+'/data_with_prio_cpp', delimiter=';')
data_with_prio_posix = genfromtxt(data_dir+'/data_with_prio_posix', delimiter=';')
data_node = genfromtxt(data_dir+'/data_node', delimiter=';')
data_wasmtime = genfromtxt(data_dir+'/data_wasmtime', delimiter=';')
data_wamr = genfromtxt(data_dir+'/data_wamr', delimiter=';')
data_wasmer_singlepass = genfromtxt(data_dir+'/data_wasmer_singlepass', delimiter=';')
data_wasmer_cranelift = genfromtxt(data_dir+'/data_wasmer_cranelift', delimiter=';')
data_wasmer_llvm = genfromtxt(data_dir+'/data_wasmer_llvm', delimiter=';')

fig, axs = plt.subplots(nrows=3, ncols=3, figsize=(6, 6), sharey=True)
axs[0, 0].hist(data_no_prio, range=(0,200), bins=100)
axs[0, 0].set_title('C++')

axs[0, 1].hist(data_with_prio_cpp, range=(0,200), bins=100)
axs[0, 1].set_title('C++ (prio/C++ sleep)')

axs[0, 2].hist(data_with_prio_posix, range=(0,200), bins=100)
axs[0, 2].set_title('C++ (pri/POSIX sleep)')

axs[1, 0].hist(data_node, range=(0,200), bins=100)
axs[1, 0].set_title('node')

axs[1, 1].hist(data_wasmtime, range=(0,200), bins=100)
axs[1, 1].set_title('wasmtime')

axs[1, 2].hist(data_wamr, range=(0,200), bins=100)
axs[1, 2].set_title('wamr')

axs[2, 0].hist(data_wasmer_singlepass, range=(0,2500), bins=100)
axs[2, 0].set_title('wasmer singlepass')

axs[2, 1].hist(data_wasmer_cranelift, range=(0,2500), bins=100)
axs[2, 1].set_title('wasmer cranelift')

axs[2, 2].hist(data_wasmer_llvm, range=(0,2500), bins=100)
axs[2, 2].set_title('wasmer llvm')

# axs[1, 2].axis('off')

fig.subplots_adjust(hspace=0.4)

pdf.savefig()

plt.savefig('hist.pdf')
plt.close()
plt.boxplot([data_no_prio, data_with_prio_cpp, data_with_prio_posix, data_node, data_wasmtime, data_wamr, data_wasmer_singlepass, data_wasmer_cranelift, data_wasmer_llvm], labels=['no_prio', 'with_prio_cpp', 'with_prio_posix', 'node', 'wasmtime', 'wamr', 'wasmer_singlepass', 'wasmer_cranelift', 'wasmer_llvm'])
plt.savefig('hist2.pdf')

pdf.savefig()
pdf.close()

print('Graph generated: ' + output_pdf)