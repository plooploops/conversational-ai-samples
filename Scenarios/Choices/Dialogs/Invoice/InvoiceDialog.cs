using ArtDevops.Dialogs.CancelAndHelp;
using ArtDevops.Models;
using Microsoft.Bot.Builder;
using Microsoft.Bot.Builder.Dialogs;
using System.Threading;
using System.Threading.Tasks;

namespace ArtDevops.Dialogs.Policy
{
    public class InvoiceDialog : CancelAndHelpDialog
    {
        private const string textPromptName = "textChoice";
        private IStatePropertyAccessor<GlobalUserState> _globalUserStateAccessor;

        public InvoiceDialog(UserState userState) : base(nameof(InvoiceDialog))
        {
            _globalUserStateAccessor = userState.CreateProperty<GlobalUserState>(nameof(GlobalUserState));

            var waterfallSteps = new WaterfallStep[]
            {
                AskForQuestionAsync,
                DeployAnswerAsync,
            };

            AddDialog(new WaterfallDialog(nameof(WaterfallDialog), waterfallSteps));
            AddDialog(new TextPrompt(textPromptName));

            InitialDialogId = nameof(WaterfallDialog);
        }

        private async Task<DialogTurnResult> AskForQuestionAsync(WaterfallStepContext stepContext, CancellationToken cancellationToken)
        {
            var state = await _globalUserStateAccessor.GetAsync(stepContext.Context, () => new GlobalUserState());

            return await stepContext.PromptAsync(textPromptName,
                    new PromptOptions
                    {
                        Prompt = stepContext.Context.Activity.CreateReply($"Ahora estás en el diálogo de **Facturas** {state.Name}")
                    });
        }

        private async Task<DialogTurnResult> DeployAnswerAsync(WaterfallStepContext stepContext, CancellationToken cancellationToken)
        {
            var givenAnswer = stepContext.Result.ToString();

            return await stepContext.ReplaceDialogAsync(nameof(PolicyDialog), cancellationToken: cancellationToken);
        }
    }
}
