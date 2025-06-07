# SkyrimAxePotionMod

## 📦 插件版本信息

- 🔧 插件名称：SkyrimAxePotionMod
- 🕹️ 游戏版本：Skyrim Special Edition 1.5.97.0
- 🛠️ 使用逆向库：[CommonLibSSE-NG](https://github.com/CharmedBaryon/CommonLibSSE-NG)
- 💡 开发平台：C++17 + CMake + Visual Studio 2022
- 📚 依赖管理：

- 使用 [vcpkg](https://github.com/microsoft/vcpkg) 管理 C++ 依赖项；
- 使用 [CommonLibSSE-NG](https://github.com/CharmedBaryon/CommonLibSSE-NG) 作为 Skyrim 的逆向接口库；
- 项目结构基于其模板进行配置，自动引入所需的头文件、链接库以及 SKSE 插件所需的构建宏；
- 通过 CMake 与 vcpkg 集成，确保在不同机器上可复现构建环境。


---

## 📖 插件功能说明

这是一个简单的 SKSE 插件，主要实现以下功能：

- 当玩家挥动特定武器（诺德手斧）时，将自动生成一瓶药水添加到玩家背包中。
- 插件通过监听 `SKSE::ActionEvent` 事件实现该功能，并进行了完整的防御性编程处理，以提高稳定性。

---

## ⚙️ 环境设置与工具依赖

本项目使用现代 C++ 构建工具，并依赖于 CommonLibSSE NG 框架。  
**建议参考此中文分步教程**来搭建本地环境：  
📖 [插件开发环境设置教程（中文）](https://github.com/gottyduke/PluginTutorialCN/blob/master/docs/setup/Setup.md)

---

## 🧰 安装与配置

1. 使用支持 `CommonLibSSE-NG` 的开发模板构建本项目。
2. 将编译生成的 `.dll` 放入 `Skyrim\Data\SKSE\Plugins` 目录中。
3. 确保游戏版本为 **1.5.97.0**，并已正确安装 **SKSE**。

---

## 🪵 日志支持（logger.h）

本项目引用了 [`logger.h`](https://github.com/SkyrimScripting/SKSE_Templates) 文件用于调试日志输出，该文件遵循 MIT 协议，允许自由复制使用。

---

## 🧠 项目定位与学习目标

此项目为作者学习 **逆向工程 + SKSE 插件开发 + C++ 防御性设计** 的练习项目，重点不在功能本身，而在于：

- 构建一个稳定可靠的事件监听框架；
- 理解黑盒系统的指针稳定性问题；

---

## 🧾 致谢与引用

- CommonLibSSE-NG by [CharmedBaryon](https://github.com/CharmedBaryon)
- logger.h 模板 by [SkyrimScripting](https://github.com/SkyrimScripting/SKSE_Templates)

---

## 🔓 License

本项目为学习用途，遵循 MIT License。

