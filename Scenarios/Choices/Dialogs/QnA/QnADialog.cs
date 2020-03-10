using ArtDevops.Dialogs.CancelAndHelp;
using ArtDevops.Models;
using Microsoft.Bot.Builder;
using Microsoft.Bot.Builder.Dialogs;
using QnA_Interactive;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace ArtDevops.Dialogs.QnA
{
    public class QnADialog : CancelAndHelpDialog
    {
        private const string textPromptName = "textChoice";
        private IStatePropertyAccessor<GlobalUserState> _globalUserStateAccessor;
        QnAHelper qnaHandler;

        public QnADialog(UserState userState) : base(nameof(QnADialog))
        {
            _globalUserStateAccessor = userState.CreateProperty<GlobalUserState>(nameof(GlobalUserState));

            var waterfallSteps = new WaterfallStep[]
            {
                AskForQuestionAsync,
                DeployAnswerAsync,
            };

            AddDialog(new WaterfallDialog(nameof(WaterfallDialog), waterfallSteps));
            AddDialog(new TextPrompt(textPromptName));
            qnaHandler = new QnAHelper("genericqna", "96ec4044-8149-44a8-a6db-c875a2595140", "EndpointKey 455ea526-1307-46bd-97aa-52abe80ebcd5");

            InitialDialogId = nameof(WaterfallDialog);
        }

        private async Task<DialogTurnResult> AskForQuestionAsync(WaterfallStepContext stepContext, CancellationToken cancellationToken)
        {
            var state = await _globalUserStateAccessor.GetAsync(stepContext.Context, () => new GlobalUserState());

            if (state.DidUserMadeQuestion == false)
            {
                state.DidUserMadeQuestion = true;
                return await stepContext.PromptAsync(textPromptName,
                    new PromptOptions
                    {
                        Prompt = stepContext.Context.Activity.CreateReply(string.Format(QnADialogStrings.Welcome, state.Name))
                    });
            }
            else
            {
                return await stepContext.PromptAsync(textPromptName,
                    new PromptOptions
                    {
                        Prompt = stepContext.Context.Activity.CreateReply(string.Format(QnADialogStrings.QuestionReprompt, state.Name))
                    });
            }
        }

        private async Task<DialogTurnResult> DeployAnswerAsync(WaterfallStepContext stepContext, CancellationToken cancellationToken)
        {
            var givenAnswer = stepContext.Result.ToString();
            
            if (givenAnswer == QnADialogStrings.BackToRoot)
            {
                return await stepContext.EndDialogAsync(cancellationToken: cancellationToken);
            }
            else
            {
                qnaHandler.CreateAnswer(givenAnswer, stepContext.Context);
                return await stepContext.ReplaceDialogAsync(nameof(QnADialog), cancellationToken: cancellationToken);
            }            
        }
    }
}
