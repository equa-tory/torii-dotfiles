-- Springs
hl.curve("s_fast",          { type = "spring", mass = 1, stiffness = 600, dampening = 49 })
hl.curve("s_default",       { type = "spring", mass = 1, stiffness = 300, dampening = 30 })
hl.curve("s_slow",          { type = "spring", mass = 1, stiffness = 160, dampening = 25 })

hl.curve("e_fast",          { type = "spring", mass = 1, stiffness = 3800,dampening = 123 })
hl.curve("e_default",       { type = "spring", mass = 1, stiffness = 1600,dampening = 80 })
hl.curve("e_slow",          { type = "spring", mass = 1, stiffness = 800, dampening = 57 })

-- Bazier for layers
hl.curve("standart",        { type = "bezier", points = { {0.2, 0.0}, {0.0, 1.0} } })
hl.curve("ephasized_accel", { type = "bezier", points = { {0.3, 0.0}, {0.8, 0.15} } })



-- Animations
hl.animation({ leaf = "windows",       enabled = true,  speed = 5, spring = "s_default" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 5, spring = "s_default", style = "popin 92%"})
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 2, spring = "s_default",       style = "popin 92%" })
hl.animation({ leaf = "windowsMove",   enabled = true,  speed = 5, spring = "s_default" })

hl.animation({ leaf = "layers",        enabled = true,  speed = 3,    bezier = "standart", style = "fade" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 3,    bezier = "standart", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 2.5,  bezier = "ephasized_accel",     style = "fade" }) 

hl.animation({ leaf = "fade",          enabled = true,  speed = 2, spring = "e_default" })        
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 2, spring = "s_default" })    

hl.animation({ leaf = "workspaces",    enabled = true,  speed = 5, spring = "s_default", style = "slide" })
hl.animation({ leaf = "specialWorkspace",    enabled = true,  speed = 3.5, spring = "s_default", style = "slidevert" })
