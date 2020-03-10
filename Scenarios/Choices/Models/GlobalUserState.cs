namespace ArtDevops.Models
{
    public class GlobalUserState
    {
        public bool DidBotWelcomeUser { get; set; } = false;

        public string Name { get; set; }

        public bool DidUserGaveName { get; set; }

        public bool DidUserMadeQuestion { get; set; }
    }
}
