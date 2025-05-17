#!/bin/bash

# Define paths and required tools
GGWAVE_DIR="$HOME/ggwave"
TOOLS=("cmake" "make" "git" "wget" "gcc" "g++" "libsdl2-dev" "ffmpeg" "python3-pip")
BUILD_DIR="$GGWAVE_DIR/build/bin"

# Helper function to display usage
usage() {
    echo "Usage: $0 [option]"
    echo "Options:"
    echo "  -install    Install and build ggwave with dependencies"
    echo "  -cleanup    Remove everything installed by the script"
    echo "  -encode     Encode text to .wav file using ggwave"
    echo "  -decode     Decode text from .wav file using ggwave"
    echo "  -help       Display this help message"
}

# Check if necessary tools are installed
check_tools() {
    echo "Checking for required tools..."
    for tool in "${TOOLS[@]}"; do
        if [[ "$tool" == "libsdl2-dev" || "$tool" == "python3-pip" ]]; then
            dpkg -l | grep -q "$tool" || { echo "Error: $tool is not installed."; exit 1; }
        else
            command -v $tool &>/dev/null || { echo "Error: $tool is not installed."; exit 1; }
        fi
    done
    echo "All required tools are installed."
}
# Install the repository, dependencies, and compile
install() {
    echo "Cloning the ggwave repository (recursive)..."
    git clone --recursive https://github.com/ggerganov/ggwave "$GGWAVE_DIR" || { echo "Error cloning repository."; exit 1; }
    cd "$GGWAVE_DIR" || exit 1

    echo "Installing dependencies..."
    sudo apt update
    sudo apt install -y libsdl2-dev python3-pip || { echo "Error installing dependencies."; exit 1; }

    echo "Building ggwave..."
    mkdir -p build && cd build
    cmake .. || { echo "CMake configuration failed."; exit 1; }
    make || { echo "Build failed."; exit 1; }

    echo "Installation and build complete."
}

# Cleanup installed files and repository
cleanup() {
    echo "Cleaning up installed files..."
    rm -rf "$GGWAVE_DIR"
    echo "Cleanup complete."
}

# Encode text to .wav file
encode() {
    # Check if necessary tools and dependencies are available
    check_tools

    echo "Enter the filename for the output .wav file (without extension):"
    read -r filename
    echo "Enter the text you want to encode:"
    read -r text

    # Remove emojis from the text
    text=$(echo "$text" | sed -e 's/[^[:print:][:space:]]//g')

    # Truncate the text to 140 bytes
    truncated_text=$(echo -n "$text" | cut -b 1-140)

    # Check if the text length exceeds 140 bytes
    if [ $(echo -n "$text" | wc -c) -gt 140 ]; then
        remaining_text=$(echo -n "$text" | cut -b 141-)
        # Check if terminal supports color (based on $TERM variable)
        if [[ -t 1 && ( "$TERM" == "xterm"* || "$TERM" == "screen"* || "$TERM" == "linux"* ) ]]; then
            # If color is supported, output in different colors with markers
            echo -e "\033[1;31m####### Warning: The text message exceeds 140 bytes. Only the first 140 bytes will be encoded. #######\033[0m"  # Bold, Red text
            echo -e "\033[1;32m@@@@@@@@@@ Truncated message: ${truncated_text} @@@@@@@@@@\033[0m"  # Bold, Green text
            echo -e "\033[1;34m************ Last 10 bytes of the truncated message: $(echo -n "$truncated_text" | cut -b 131-140) ************\033[0m"  # Bold, Blue text
            echo -e "\033[1;33m^^^^^^^^^^ Remaining text that was not encoded: ${remaining_text} ^^^^^^^^^^\033[0m"  # Bold, Yellow text
        else
            # If color is not supported, output normal text with markers
            echo "####### Warning: The text message exceeds 140 bytes. Only the first 140 bytes will be encoded. #######"
            echo "@@@@@@@@@@ Truncated message: ${truncated_text} @@@@@@@@@@"
            echo "************ Last 10 bytes of the truncated message: $(echo -n "$truncated_text" | cut -b 131-140) ************"
            echo "^^^^^^^^^^ Remaining text that was not encoded: ${remaining_text} ^^^^^^^^^^"
        fi
        text="$truncated_text"
    fi

    # Debugging: Echo the length of the text before writing to the file
    echo "Length of text before writing to file: $(echo -n "$text" | wc -c)"

    # Create a temporary text file in the /tmp directory
    tmp_file="/tmp/message.txt"
    echo -n "$text" > "$tmp_file"

    # Debugging: Echo the contents of the temporary text file and its length
    echo "Contents of $tmp_file:"
    cat "$tmp_file"
    echo "Length of text in $tmp_file: $(wc -c < "$tmp_file")"

    # Navigate to the build directory
    cd "$BUILD_DIR" || exit 1

    # Generate the .wav file in the original directory
    output_file="$OLDPWD/${filename}.wav"
    echo "Generating .wav file for the text: '$text'..."
    ./ggwave-to-file -f"$output_file" < "$tmp_file"

    # Remove the temporary text file
    rm "$tmp_file"

    echo "Encoding complete. The file '$filename.wav' has been generated in the directory from where the script was run."
}

# Decode text from .wav file
decode() {
    echo "Enter the filename (with .wav extension) of the .wav file you want to decode:"
    read -r wav_file

    # Ensure the file exists in the current directory
    if [[ ! -f "$wav_file" ]]; then
        echo "Error: File '$wav_file' does not exist in the current directory."
        exit 1
    fi

    # Define the path to the ggwave tools directory
    ggwave_dir="$HOME/ggwave/build/bin"
    ggwave_from_file="$ggwave_dir/ggwave-from-file"

    # Ensure ggwave-from-file exists
    if [[ ! -f "$ggwave_from_file" ]]; then
        echo "Error: ggwave-from-file not found at $ggwave_from_file"
        exit 1
    fi

    # Copy the .wav file to the ggwave directory
    cp "$wav_file" "$ggwave_dir/"

    # Navigate to the ggwave tools directory and decode the message
    cd "$ggwave_dir" || exit
    echo "Decoding the message from the .wav file..."

    # Run the decoding tool and suppress unnecessary output
    result=$(./ggwave-from-file "$wav_file" 2>/dev/null | grep -oP "(?<=Decoded message with length ).*")

    # Remove the copied .wav file after decoding
    rm "$wav_file"

    # Check if terminal supports color (based on $TERM variable)
    if [[ -t 1 && ( "$TERM" == "xterm"* || "$TERM" == "screen"* || "$TERM" == "linux"* ) ]]; then
        # If color is supported, output in cyan with bold
        echo -e "\033[1;36mDecoded message: $result\033[0m"  # Bold, Cyan text
    else
        # If color is not supported, output normal text
        echo "Decoded message: $result"
    fi
}

# Main script logic
case "$1" in
    -install)
        install
        ;;
    -cleanup)
        cleanup
        ;;
    -encode)
        encode
        ;;
    -decode)
        decode
        ;;
    -help)
        usage
        ;;
    *)
        echo "Invalid option. Use -help for usage information."
        ;;
esac