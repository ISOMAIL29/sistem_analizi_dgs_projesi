import zipfile
import xml.etree.ElementTree as ET
import sys

def extract_text(docx_path):
    try:
        with zipfile.ZipFile(docx_path) as docx:
            xml_content = docx.read('word/document.xml')
            tree = ET.fromstring(xml_content)
            namespaces = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
            
            paragraphs = tree.findall('.//w:p', namespaces)
            text_run = []
            
            for p in paragraphs:
                texts = [node.text for node in p.findall('.//w:t', namespaces) if node.text]
                if texts:
                    text_run.append("".join(texts))
            return "\n".join(text_run)
    except Exception as e:
        return str(e)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        text = extract_text(sys.argv[1])
        with open("output.txt", "w", encoding="utf-8") as f:
            f.write(text)
    else:
        print("Please provide a path.")
