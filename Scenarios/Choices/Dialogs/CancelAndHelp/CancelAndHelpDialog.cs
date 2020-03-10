using System.Threading;
using System.Threading.Tasks;
using Microsoft.Bot.Builder.Dialogs;
using Microsoft.Bot.Schema;
using ArtDevops.Dialogs.Root;

namespace ArtDevops.Dialogs.CancelAndHelp
{
    public class CancelAndHelpDialog : ComponentDialog
    {
        public CancelAndHelpDialog(string id) : base(id)
        {
        }

        protected override async Task<DialogTurnResult> OnBeginDialogAsync(DialogContext innerDc, object options, CancellationToken cancellationToken)
        {
            var result = await InterruptAsync(innerDc, cancellationToken);
            if (result != null)
            {
                return result;
            }

            return await base.OnBeginDialogAsync(innerDc, options, cancellationToken);
        }

        protected override async Task<DialogTurnResult> OnContinueDialogAsync(DialogContext innerDc, CancellationToken cancellationToken)
        {
            var result = await InterruptAsync(innerDc, cancellationToken);
            if (result != null)
            {
                return result;
            }

            return await base.OnContinueDialogAsync(innerDc, cancellationToken);
        }

        private async Task<DialogTurnResult> InterruptAsync(DialogContext innerDc, CancellationToken cancellationToken)
        {
            if (innerDc.Context.Activity.Type == ActivityTypes.Message)
            {
                string text = (string.IsNullOrEmpty(innerDc.Context.Activity.Text)) ? innerDc.Context.Activity.Value.ToString() : innerDc.Context.Activity.Text.ToLowerInvariant();

                switch (text)
                {
                    case "help":
                    case "volver":
                        //await innerDc.Context.SendActivityAsync($"Show Help...", cancellationToken: cancellationToken);
                        return await innerDc.ReplaceDialogAsync(nameof(RootDialog), cancellationToken: cancellationToken);
                    case "cancel":
                    case "quit":
                        await innerDc.Context.SendActivityAsync($"Cancelling", cancellationToken: cancellationToken);
                        return await innerDc.CancelAllDialogsAsync(cancellationToken: cancellationToken);
                }
            }
            return null;
        }
    }
}
