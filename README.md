# verify_method

<img width="2733" height="603" alt="校验方法 drawio" src="https://github.com/user-attachments/assets/df116538-38bb-4f56-a918-a12a08eccca9" />

## 验证OTS时间戳

[OpenTimeStamps](https://opentimestamps.org/)时间戳可以证明某私钥是在某一时间段签名的。可以确认该签名是否在私钥过期前签名。

验证方法：

去https://opentimestamps.org/#info

然后把sha256sum.txt.asc.ots文件和对应的sha256sum.txt.asc文件丢进去即可

<img width="50%" width="2141" height="1233" alt="image" src="https://github.com/user-attachments/assets/90d14664-8d29-4854-8463-ac537b51181c" />

## 验证sha256sum

有两种方法

### OpenGPG

安装[gpg4win](https://www.gpg4win.org/)

打开Kleopatra，配置密钥服务器：keys.openpgp.org

<img width="33%" width="1322" height="1186" alt="image" src="https://github.com/user-attachments/assets/15e64cd2-a765-42ee-a541-2ffca3774f16" />

搜索笔者的邮箱：rocyax@gmail.com

<img width="50%" width="2005" height="856" alt="image" src="https://github.com/user-attachments/assets/b3774bcb-c984-4167-86e6-3b58bdc15cae" />

导入证书

比对主公钥指纹(必须认真比对！)：

```
BDAF8C63A4D289E6BB98894B1F14D32AA81387E8
```

<img width="50%" width="1712" height="866" alt="image" src="https://github.com/user-attachments/assets/0a42aa72-88bc-452b-9998-5148f82a7f32" />

然后对sha256sum.txt.asc打开右键菜单，选择"Decrypt and Verify"

理想状态如下所示:

<img width="50%" width="1280" height="1070" alt="opengpg" src="https://github.com/user-attachments/assets/3eba519f-c801-41c5-a94e-174929ab1792" />

警告不用管, 只要公钥指纹能对上就行. \*如果想要完全消除警告，需要用你自己的证书对我的公钥进行签名. 

<img width="50%" width="1280" height="664" alt="Snipaste_2026-07-04_15-55-59" src="https://github.com/user-attachments/assets/6ee40dcd-3d9a-4f72-9653-15492c98238e" />

这是**不能接受**的结果, sha256sum.txt可能被篡改了：

<img width="50%" width="1280" height="664" alt="Snipaste_2026-07-04_15-56-15" src="https://github.com/user-attachments/assets/2237ade0-16ab-4f45-a4b7-05063aaef4bf" />

### Cosign

安装Cosign:

```bash
go install github.com/sigstore/cosign/v3/cmd/cosign@latest
cosign version
```

验证

Bash:
```bash
cosign verify-blob sha256sum.txt \
  --bundle sha256sum.txt.sigstore.json \
  --certificate-identity rocyax@gmail.com \
  --certificate-oidc-issuer https://github.com/login/oauth
```

Powershell:
```powershell
cosign verify-blob sha256sum.txt `
  --bundle sha256sum.txt.sigstore.json `
  --certificate-identity rocyax@gmail.com `
  --certificate-oidc-issuer https://github.com/login/oauth
```

注意笔者使用的信息：
identity：rocyax@gmail.com
issuer：https://github.com/login/oauth

接受的结果：`Verified OK`

不接受的结果：`Error: failed to verify signature: could not verify message: invalid signature when validating ASN.1 encoded signature
error during command execution: failed to verify signature: could not verify message: invalid signature when validating ASN.1 encoded signature`

## 使用sha256sum校验游戏文件

在仓库里下载Verify-FileTree.ps1(Windows)或verify-filetree.sh(Linux)

本脚本可以验证：
1. 证明游戏文件的hash有效
2. 证明游戏目录没有增添/缺失文件

运行方法，在游戏根目录外，运行(示例)
```powershell
.\Verify-FileTree.ps1 -Root .\kinky-dungeon-win_64
```

Linux:
```bash
./verify-filetree.sh kinky-dungeon-linux_64/sha256sum.txt
```

\* 笔者处理的Windows CRLF行尾. 这使得Windows和Linux的sha256sum.txt可以交叉验证.

理想结果
```
[2/3] Comparing file set...
[3/3] File set is exact.
All files OK.
```

不接受的结果
```
File set check FAILED.
```

