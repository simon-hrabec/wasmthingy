import matplotlib.pyplot as plt
import numpy as np
from numpy import genfromtxt
from matplotlib.backends.backend_pdf import PdfPages

pdf = PdfPages('rp4.pdf')

data_node = genfromtxt('output/data_node', delimiter=';')
data_no_prio = genfromtxt('output/data_no_prio', delimiter=';')
data_with_prio_cpp = genfromtxt('output/data_with_prio_cpp', delimiter=';')
data_with_prio_posix = genfromtxt('output/data_with_prio_posix', delimiter=';')
data_wasmtime = genfromtxt('output/data_wasmtime', delimiter=';')
data_wasmer = genfromtxt('output/data_wasmer', delimiter=';')

print(data_node)
print(data_node.size)
print(data_node.shape)
print(data_node.ndim)
# print(x)



x = np.random.normal(170, 10, 250)
# plt.boxplot(x)

fig, axs = plt.subplots(nrows=2, ncols=3, figsize=(6, 6), sharey=True)
axs[0, 0].hist(data_node, range=(0,200), bins=100)
axs[0, 0].set_title('Node WASM')

axs[0, 1].hist(data_no_prio, range=(0,200), bins=100)
axs[0, 1].set_title('C (no prio)')

axs[0, 2].hist(data_with_prio_cpp, range=(0,200), bins=100)
axs[0, 2].set_title('C (with prio)')

axs[1, 0].hist(data_wasmtime, range=(0,200), bins=100)
axs[1, 0].set_title('wasmtime')

axs[1, 1].hist(data_wasmer, range=(0,2500), bins=100)
axs[1, 1].set_title('wasmer')

axs[1, 2].hist(data_with_prio_posix, range=(0,200), bins=100)
axs[1, 2].set_title('C (with prio)')

# axs[1, 2].axis('off')

fig.subplots_adjust(hspace=0.4)

# plt.hist(x)
# plt.hist(x)
# plt.hist(x)
# plt.hist(my_data, range=(50,100), bins=51)
# plt.show()

pdf.savefig()

plt.savefig('hist.pdf')
plt.close()
plt.boxplot([data_node, data_no_prio, data_with_prio_cpp, data_with_prio_posix, data_wasmtime, data_wasmer], labels=['Node WASM', 'C (no prio)', 'C (with prio - C++)', 'C (with prio - posix)', 'wasmtime', 'wasmer'])
plt.savefig('hist2.pdf')

pdf.savefig()
pdf.close()

print("Hello world")