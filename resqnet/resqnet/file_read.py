import os

# List of file extensions to read
EXTENSIONS = {'.txt', '.dart', '.c', '.py', '.java', '.js', '.cpp', '.h', '.cs', '.rb', '.go', '.ts','.yaml','.xml'}

def read_files_and_write_output(start_dir, base_dir, output_file, script_name):
    with open(output_file, 'w', encoding='utf-8') as out_f:
        for root, _, files in os.walk(start_dir):
            for file in files:
                # Skip the script file itself
                if file == script_name:
                    continue
                if os.path.splitext(file)[1].lower() in EXTENSIONS:
                    file_path = os.path.join(root, file)
                    # Relative path from base_dir to include the script directory name
                    relative_path = os.path.relpath(file_path, base_dir)
                    out_f.write(f"------{relative_path}\n")
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                        out_f.write(content)
                    except Exception as e:
                        out_f.write(f"[Error reading file: {e}]\n")
                    out_f.write("\n" + "="*80 + "\n\n")

if __name__ == "__main__":
    script_path = os.path.abspath(__file__)
    script_dir = os.path.dirname(script_path)
    base_dir = os.path.dirname(script_dir)  # Parent directory of script directory
    output_filename = os.path.join(script_dir, "output.txt")
    script_filename = os.path.basename(script_path)

    read_files_and_write_output(script_dir, base_dir, output_filename, script_filename)
    print(f"Finished writing contents to {output_filename}")
