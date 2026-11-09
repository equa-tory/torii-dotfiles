# Minecraft audio

The repository preserves the working local OpenAL Soft configuration in `.alsoftrc`:

```ini
drivers=pulse
```

This selects the PulseAudio backend for OpenAL Soft. Torii's installer links it to `~/.alsoftrc` as part of the **torii** configs; the desktop stow installation includes it too. Existing files are backed up by the standard linker.

Apply just this configuration with `bash packages/link.sh paths .alsoftrc`, then restart Minecraft. No audio service restart is needed to install the file. This user-wide OpenAL setting is the existing Minecraft audio workaround, not a Minecraft-instance-specific setting.
