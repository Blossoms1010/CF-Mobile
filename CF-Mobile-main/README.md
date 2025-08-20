# 📱 Codeforces iOS 客户端  

一个 **轻量级 Codeforces 助手**，支持 **题目浏览、代码编辑、个人数据可视化** 等功能。  
让你在手机端也能方便刷题、写代码、看数据。  

---

## 📑 功能目录
- [0x01 个人数据可视化](#0x01-个人数据可视化)  
- [0x02 代码编辑](#0x02-代码编辑)  
- [0x03 比赛情况与题面浏览](#0x03-比赛情况与题面浏览)  
- [0x04 关于](#0x04-关于)  

---

## 0x01 个人数据可视化  

在 **“我的”** 页面输入 handle 后可加载数据信息：

- 显示 **段位称号、昵称、Rating 值、Rating 曲线**  
- 展示 **总 AC 数、30 天内 AC 数、连续 AC 天数**  

<img src="https://github.com/user-attachments/assets/865a361b-4566-40e8-8e6a-40f5e2755403" width="800" />  
<img src="https://github.com/user-attachments/assets/befa0462-d64e-4bad-9c5b-a0b363cd2714" width="800" />  

---

📊 **数据可视化内容**：  
- 热力图（基于每日最高分着色）  
- 通过题的分数分布  
- 按标签分类的通过题占比  

<img src="https://github.com/user-attachments/assets/28803131-3e9f-4b2f-bc81-733c45fdc135" width="800" />  
<img src="https://github.com/user-attachments/assets/f532c072-00ac-4df8-a8e6-b8bf67985f46" width="800" />  

---

📜 **提交记录展示**：  
- 展示最近提交记录，可展开查看全部提交  
- 绑定账号后可点击跳转至官网查看详细代码  

<img src="https://github.com/user-attachments/assets/ec83ce1d-d414-4f45-8534-d99e19a9cd65" width="800" />  
<img src="https://github.com/user-attachments/assets/b90dbca4-df05-41f0-bb92-7842e89c86d9" width="800" />  

---

⚙️ **设置页功能**：  
- 登录 Codeforces 账号（采集 Cookie，用于代码提交与提交详情查看）  
- 配置 AI 翻译（题面翻译）  

<img src="https://github.com/user-attachments/assets/599d31c2-fe7e-441a-a701-01756350cb61" width="800" />  

---

## 0x02 代码编辑  

✏️ 内置 **Monaco Editor** 编辑器，支持：  
- C++、Java、Python 语法高亮  
- 文件管理（删除 / 重命名）  
- 字号调节、自动保存、缩略图  
- 跟随系统的颜色主题  

<img src="https://github.com/user-attachments/assets/f77f8294-75df-413e-b21a-4cb8ad802156" width="800" />  
<img src="https://github.com/user-attachments/assets/2c74546e-5dc5-4f98-af0d-978019bcedac" width="800" />  
<img src="https://github.com/user-attachments/assets/2c6ecff6-20fc-4926-a451-35e53f26f8f9" width="500" />  

---

⚡ **远程运行**：  
- 配置 Judge0，支持代码运行与 I/O  
- 运行状态：Running / Passed / Failed / Time Out  
- 返回运行时间  

![运行状态](https://github.com/user-attachments/assets/3edb219f-6915-4e00-88eb-fb5b063aafe2)  
![运行结果](https://github.com/user-attachments/assets/9c5e5ec9-285f-4898-a680-e27a30e8994d)  

---

🚀 **一键提交**（需登录账号，功能测试中）：  

<img src="https://github.com/user-attachments/assets/f0f6e2a3-4cab-4c66-ada1-65388bb8f2fa" width="800" />  

---

## 0x03 比赛情况与题面浏览  

🏆 **比赛情况展示**：  
- 每场比赛的通过情况一览  
- 题目标题按分数段位着色  
- **绿色**：通过；**红色**：尝试未通过  

![比赛结果1](https://github.com/user-attachments/assets/0c4d007f-a187-4b9c-8cce-7966fefa85d2)  
![比赛结果2](https://github.com/user-attachments/assets/99f67034-7f8d-43c3-96d0-c7b93f2f031a)  

---

📖 **题面浏览**：  
- 点击题目可自动提取题面  
- 可一键下载题目文件与样例  
- 查看提交记录（书面按钮）  
- 配置 AI 翻译可一键翻译题面  

<img src="https://github.com/user-attachments/assets/c203a026-2a0a-4e9d-8457-e7ee49ed472b" width="800" />  
<img src="https://github.com/user-attachments/assets/ff09a5eb-fa20-453d-a07a-a4b50a620bef" width="800" />  

---

## 0x04 关于  

几天前cf维护生活节奏被打乱了，于是突发其想，熬了三天大夜，用cursor加GPT 5草草做了这个app。本人大一升大二，0开发经验，越做到后面想要实现的功能越多发现就越麻烦，要修复的bug越多，索性放弃了开源欢迎感兴趣的小伙伴叉叉我（

---

## 📌 已知待完善的地方
- [ ] 代码提交功能不稳定
- [ ] 语言支持只有cpp
- [ ] 题面翻译不能缓存，而且会破坏latex渲染
- [ ] 登入信息的cookie常常出bug，明明登入了却提示未登入

---

## 📄 License
CF：XDU_B1ossoms
Email:2750437093@qq.com

---

## ⭐ 支持项目
如果你觉得这个项目对你有帮助，欢迎点个 Star ⭐  
