#!/usr/bin/env python3

import sys
import re
from datetime import datetime

def update_appcast(version, build_number, signature, length, release_notes, dmg_name):
    appcast_file = 'appcast.xml'
    
    # 读取现有内容
    with open(appcast_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 准备新的 item
    pub_date = datetime.now().astimezone().strftime('%a, %d %b %Y %H:%M:%S %z')
    
    new_item = f'''
        <item>
            <title>Version {version}</title>
            <pubDate>{pub_date}</pubDate>
            <sparkle:version>{build_number}</sparkle:version>
            <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <description><![CDATA[
                <h2>{release_notes}</h2>
                <h3>🎉 新功能</h3>
                <ul>
                    <li>{release_notes}</li>
                </ul>
                <h3>📝 技术改进</h3>
                <ul>
                    <li>性能优化</li>
                    <li>稳定性改进</li>
                </ul>
            ]]></description>
            <enclosure
                url="https://github.com/hmilyfyj/PasteMemo-app/releases/download/v{version}/{dmg_name}"
                sparkle:edSignature="{signature}"
                length="{length}"
                type="application/octet-stream"
            />
        </item>'''
    
    # 在第一个 <item> 之前插入新的 item
    # 找到第一个 <item> 标签的位置
    pattern = r'(\s*<item>)'
    match = re.search(pattern, content)
    
    if match:
        # 在匹配到的位置插入新的 item
        insert_pos = match.start()
        new_content = content[:insert_pos] + new_item + content[insert_pos:]
        
        # 写入文件
        with open(appcast_file, 'w', encoding='utf-8') as f:
            f.write(new_content)
        
        print(f"✅ appcast.xml 已更新，添加了版本 {version}")
        return True
    else:
        print("❌ 错误：无法找到 <item> 标签")
        return False

if __name__ == '__main__':
    if len(sys.argv) != 7:
        print("用法: python3 update_appcast.py <版本号> <构建号> <签名> <文件大小> <更新说明> <DMG文件名>")
        print(f"当前参数数量: {len(sys.argv)}")
        print(f"参数列表: {sys.argv}")
        sys.exit(1)
    
    version = sys.argv[1]
    build_number = sys.argv[2]
    signature = sys.argv[3]
    length = sys.argv[4]
    release_notes = sys.argv[5]
    dmg_name = sys.argv[6]
    
    success = update_appcast(version, build_number, signature, length, release_notes, dmg_name)
    sys.exit(0 if success else 1)
