function gen-pass
  gpg --gen-random --armor 1 32 | tr -d '/=+' | cut -c -16 | awk '{gsub(/(.{4})/, "&-"); sub(/-$/, ""); print}'
end
