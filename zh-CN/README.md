# SMOKE [![DOI](https://zenodo.org/badge/39790736.svg)](https://zenodo.org/badge/latestdoi/39790736)

稀疏矩阵运算符内核排放（The Sparse Matrix Operator Kernel Emissions，SMOKE）模型系统最初是由MCNC开发的，旨在将排放数据处理与高性能计算（high-performance computing，HPC）稀疏矩阵算法（sparse-matrix algorithms）集成在一起。SMOKE现在由环境研究所开发，并得到了社区模型和分析系统（Community Modeling and Analysis System，CMAS）的支持。

SMOKE主要是一种排放处理系统，旨在创建网格化的、独立的逐小时排放量数据，以输入到各种空气质量模型中，例如CMAQ、REMSAD、CAMX和UAM。SMOKE支持面源、生物源、移动源（道路和非道路）以及点源排放的基本污染物、颗粒物和有毒污染物的处理。对于生物排放模型，SMOKE使用生物源排放清单系统（Biogenic Emission Inventory System）的2.5版本（BEIS2）、3.09版本和3.14版本（BEIS3）。SMOKE还与道路排放模型MOBILE6和MOVES集成在一起。

SMOKE使用的稀疏矩阵方法可以快速、灵活地处理排放数据。由于SMOKE使用一系列矩阵计算，而不是先前系统使用的效率较低的顺序方法，因此可以进行快速处理。同时，SMOKE灵活的处理过程可以将清单增加、控制、化学物种、时间分配和空间分配的处理尽可能地分成独立的步骤。这些子步骤的处理结果在使用向量矩阵乘法的最后处理阶段合并在一起。这意味着可以单独执行和合并各个步骤（例如增加新的控制措施或处理用于不同的网格设置），而不必重做其他所有处理。

最初的SMOKE概念在1990年代初期由Carlie Coats博士在MCNC提出。Marc Houyoux负责SMOKE的开发，直到2002年离开美国EPA空气质量计划和标准办公室。随着CEMPD的积极发展，SMOKE的主要开发工作在2005年从Catherine Seppanen移交给了B.H.Baek博士。尽管在CEMPD之外也进行了一些SMOKE的开发，但主要的开发线由B.H.Baek博士管理，并获得了美国EPA的资助。

# 支持SMOKE的输入数据文件

SMOKE输入数据包括排放清单、时间和化学形态概况、空间替代物、网格气象资料和土地利用数据，以及其他用于指定排放时间、位置和化学性质的辅助文件。部分示例数据随同SMOKE一起发布，可用于模型入门。但要注意示例文件仅用于演示目的，并不能用于实际的建模。

除气象之外的SMOKE输入数据的主要来源是美国EPA清单和排放因子交换所（Clearinghouse for Inventories and Emissions Factors，CHIEF）。美国EPA空气质量计划和标准办公室（Office of Air Quality Planning and Standards，OAQPS）排放清单和分析小组（Emissions Inventory and Analysis Group，EIAG）为不同模型平台提供SMOKE输入数据。这些平台不仅包括基本空气污染物（criteria air pollutants，CAPs）和有害空气污染物（hazardous air pollutants，HAPs）的NEI，还包括EPA创建的用于SMOKE的所有辅助数据文件。EPA通过CHIEF提供这些数据。

SMOKE必须使用MM5、WRF或类似模型生成的气象数据，同时必须使用MCIP之类的程序对以上气象模型的输出数据进行处理以满足SMOKE格式要求。

[SMOKE用户手册](documentation/README.md)